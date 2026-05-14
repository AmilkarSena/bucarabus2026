import { useFormValidation } from './useFormValidation'

/**
 * Composable que define el motor de validación para el registro y edición de buses.
 * 
 * Su responsabilidad es asegurar que los datos cumplen con los estándares legales y técnicos:
 * 1. Formatos Estrictos (Regex): Valida placas colombianas (ABC123), códigos AMB (AMB-0000) y colores Hexadecimales.
 * 2. Reglas Temporales: Controla que el año del modelo sea coherente con el año actual (incluyendo el año siguiente).
 * 3. Integridad de Datos: Valida obligatoriedad y rangos de capacidad (10-200 pasajeros).
 * 4. Validación Desacoplada: Permite validar campos individualmente (al perder el foco/@blur) o el formulario completo.
 * 
 * @param {Ref} formData - Referencia al objeto de datos del bus a validar.
 * @param {Object} dependencies - Dependencias externas (ej: currentYear para validación de modelo).
 * @returns {Object} Errores reactivos y métodos de validación.
 */

// Expresiones Regulares
const PLATE_REGEX = /^[A-Z]{3}[0-9]{3}$/
const AMB_CODE_REGEX = /^AMB-[0-9]{4}$/
const HEX_COLOR_REGEX = /^#[0-9A-Fa-f]{6}$/

export function useBusValidation(formData, dependencies = {}) {
  const { currentYear = new Date().getFullYear() } = dependencies
  const { errors, validateField, resetErrors } = useFormValidation()

  // Funciones de validación individuales (para eventos @blur)
  const validatePlateField = () => {
    validateField('plate_number', formData.value.plate_number, [
      v => !!v?.trim() || 'La placa es obligatoria',
      v => PLATE_REGEX.test(v) || 'Formato inválido. Debe ser ABC123 (3 letras + 3 números)'
    ])
  }

  const validateAmbCodeField = () => {
    validateField('amb_code', formData.value.amb_code, [
      v => !!v?.trim() || 'El código AMB es obligatorio',
      v => AMB_CODE_REGEX.test(v) || 'Formato inválido. Debe ser AMB-#### (ej: AMB-0001)'
    ])
  }

  const validateCodeInternalField = () => {
    validateField('code_internal', formData.value.code_internal, [
      v => !!v?.trim() || 'El código interno es obligatorio',
      v => (v?.trim().length >= 2) || 'Mínimo 2 caracteres'
    ])
  }

  const validateIdCompanyField = () => {
    validateField('id_company', formData.value.id_company, [
      v => !!v || 'Debe seleccionar una compañía'
    ])
  }

  const validateModelYearField = () => {
    validateField('model_year', formData.value.model_year, [
      v => !!v || 'El año del modelo es obligatorio',
      v => (v >= 1990 && v <= currentYear + 1) || `El año debe estar entre 1990 y ${currentYear + 1}`
    ])
  }

  const validateCapacityField = () => {
    validateField('capacity_bus', formData.value.capacity_bus, [
      v => !!v || 'La capacidad es obligatoria',
      v => (v >= 10 && v <= 200) || 'La capacidad debe estar entre 10 y 200'
    ])
  }

  const validateColorBusField = () => {
    validateField('color_bus', formData.value.color_bus, [
      v => !!v?.trim() || 'El color es obligatorio',
      v => (v?.trim().length >= 2) || 'Mínimo 2 caracteres'
    ])
  }

  const validateIdOwnerField = () => {
    validateField('id_owner', formData.value.id_owner, [
      v => !!v || 'Debe seleccionar un propietario'
    ])
  }

  const validateModelNameField = () => {
    validateField('model_name', formData.value.model_name, [
      v => (!v || v.trim().length >= 2) || 'Mínimo 2 caracteres'
    ])
  }

  const validateColorAppField = () => {
    validateField('color_app', formData.value.color_app, [
      v => (!v || HEX_COLOR_REGEX.test(v)) || 'Formato inválido. Debe ser #RRGGBB (ej: #FF5733)'
    ])
  }

  // Validación global del formulario
  const validateForm = () => {
    resetErrors()
    validatePlateField()
    validateAmbCodeField()
    validateCodeInternalField()
    validateIdCompanyField()
    validateModelYearField()
    validateCapacityField()
    validateColorBusField()
    validateIdOwnerField()
    validateModelNameField()
    validateColorAppField()

    return Object.keys(errors.value).length === 0
  }

  return {
    errors,
    resetErrors,
    validatePlateField,
    validateAmbCodeField,
    validateCodeInternalField,
    validateIdCompanyField,
    validateModelYearField,
    validateCapacityField,
    validateColorBusField,
    validateIdOwnerField,
    validateModelNameField,
    validateColorAppField,
    validateForm
  }
}
