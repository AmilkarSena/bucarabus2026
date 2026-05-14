import { useFormValidation } from './useFormValidation'

/**
 * Composable que define el motor de validación para el ciclo de vida de un conductor.
 * 
 * Implementa validaciones críticas para la seguridad vial y el cumplimiento legal:
 * 1. Identidad: Valida formatos de Cédula de Ciudadanía colombiana y longitud de nombres.
 * 2. Salud y Contacto: Asegura que los datos de contacto y emergencia cumplan con formatos telefónicos y de email.
 * 3. Lógica de Licencia Avanzada:
 *    - Impide registrar conductores menores de 18 años.
 *    - Valida que la fecha de vencimiento de la licencia sea coherente con la edad del conductor
 *      (bloqueando intentos de asignar vigencias superiores a las permitidas por ley).
 * 4. Integridad: Agrupa todas las reglas para una validación síncrona antes del envío al servidor.
 * 
 * @param {Ref} formData - Datos reactivos del conductor.
 * @param {Object} helpers - Funciones de cálculo externo (calculateAge, calculateMaxLicenseExpDate).
 * @returns {Object} Errores reactivos y métodos de validación granular.
 */

// =============================================
// CONSTANTES DE VALIDACIÓN
// =============================================
const EMAIL_REGEX = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/
const PHONE_REGEX = /^[0-9]{7,15}$/
const NAME_REGEX = /^[a-zA-ZáéíóúñÁÉÍÓÚÑ\s]{3,100}$/
const CEDULA_REGEX = /^[0-9]{8,13}$/
const VALID_LICENSE_CATEGORIES = ['C1', 'C2', 'C3']

export function useDriverValidation(formData, helpers) {
  const { calculateAge, calculateMaxLicenseExpDate } = helpers
  const { errors, validators, validateForm: runValidation, resetErrors } = useFormValidation()

  // Validaciones en tiempo real (on blur)
  const validateNameField = () => {
    const val = formData.value.name_driver
    if (val.length < 3) {
      errors.value.name_driver = 'El nombre debe tener al menos 3 caracteres'
    } else if (val.length > 100) {
      errors.value.name_driver = 'El nombre no puede exceder 100 caracteres'
    } else if (!NAME_REGEX.test(val)) {
      errors.value.name_driver = 'El nombre solo puede contener letras y espacios'
    } else {
      errors.value.name_driver = null
    }
  }

  const validateCedulaField = () => {
    const val = formData.value.id_driver
    if (!val) {
      errors.value.id_driver = 'La cédula es obligatoria'
    } else if (!CEDULA_REGEX.test(val)) {
      errors.value.id_driver = 'La cédula debe tener entre 8 y 13 dígitos'
    } else if (val < 1000000) {
      errors.value.id_driver = 'La cédula no es válida'
    } else {
      errors.value.id_driver = null
    }
  }

  const validatePhoneField = () => {
    const val = formData.value.phone_driver
    if (val && !PHONE_REGEX.test(val)) {
      errors.value.phone_driver = 'El teléfono debe tener entre 7 y 15 dígitos'
    } else {
      errors.value.phone_driver = null
    }
  }

  const validateEmailField = () => {
    const val = formData.value.email_driver
    if (val && !EMAIL_REGEX.test(val)) {
      errors.value.email_driver = 'El email no tiene un formato válido'
    } else if (val && val.length > 320) {
      errors.value.email_driver = 'El email es muy largo'
    } else {
      errors.value.email_driver = null
    }
  }

  const validateLicenseExpField = () => {
    const val = formData.value.license_exp
    if (!val) {
      errors.value.license_exp = 'La fecha de vencimiento es obligatoria'
    } else {
      const selectedDate = new Date(val)
      const today = new Date()
      today.setHours(0, 0, 0, 0)
      
      if (selectedDate <= today) {
        errors.value.license_exp = 'La fecha de vencimiento debe ser en el futuro'
      } else {
        const maxExpDate = calculateMaxLicenseExpDate(formData.value.birth_date)
        if (maxExpDate) {
          const maxDate = new Date(maxExpDate)
          if (selectedDate > maxDate) {
            const age = calculateAge(formData.value.birth_date)
            const years = age < 60 ? 3 : 1
            errors.value.license_exp = `Para una persona de ${age} años, la licencia vence máximo ${years} año(s) desde hoy (${maxExpDate})`
          } else {
            errors.value.license_exp = null
          }
        } else {
          errors.value.license_exp = null
        }
      }
    }
  }

  const validateBirthdateField = () => {
    const val = formData.value.birth_date
    if (!val) {
      errors.value.birth_date = null
      return
    }
    const birthDate = new Date(val)
    const today = new Date()
    
    if (birthDate >= today) {
      errors.value.birth_date = 'La fecha de nacimiento debe ser en el pasado'
    } else {
      const age = calculateAge(val)
      if (age < 18) {
        errors.value.birth_date = 'Debe ser mayor de 18 años para ser conductor'
      } else if (age > 80) {
        errors.value.birth_date = 'No se pueden registrar personas mayores de 80 años'
      } else {
        errors.value.birth_date = null
        if (formData.value.license_exp) {
          validateLicenseExpField()
        }
      }
    }
  }

  const validateForm = () => {
    const rules = {
      name_driver: [
        (val) => validators.required(val, 'El nombre es obligatorio'),
        (val) => {
          if (val && val.length < 3) return 'El nombre debe tener al menos 3 caracteres'
          if (val && val.length > 100) return 'El nombre no puede exceder 100 caracteres'
          if (val && !NAME_REGEX.test(val)) return 'El nombre solo puede contener letras y espacios'
          return null
        }
      ],
      id_driver: [
        (val) => validators.required(val, 'La cédula es obligatoria'),
        (val) => {
          if (val && !CEDULA_REGEX.test(val)) return 'La cédula debe tener entre 8 y 13 dígitos'
          if (val && val < 1000000) return 'La cédula no es válida'
          return null
        }
      ],
      phone_driver: [
        (val) => {
          if (val && !PHONE_REGEX.test(val)) return 'El teléfono debe tener entre 7 y 15 dígitos'
          return null
        }
      ],
      email_driver: [
        (val) => {
          if (val && !EMAIL_REGEX.test(val)) return 'El email no tiene un formato válido'
          if (val && val.length > 320) return 'El email es muy largo'
          return null
        }
      ],
      birth_date: [
        (val) => {
          if (!val) return null
          const birthDate = new Date(val)
          const today = new Date()
          if (birthDate >= today) return 'La fecha de nacimiento debe ser en el pasado'
          
          const age = calculateAge(val)
          if (age < 18) return 'Debe ser mayor de 18 años para ser conductor'
          return null
        }
      ],
      license_cat: [
        (val) => validators.required(val, 'La categoría de licencia es obligatoria'),
        (val) => {
          if (val && !VALID_LICENSE_CATEGORIES.includes(val)) return 'Categoría de licencia inválida'
          return null
        }
      ],
      license_exp: [
        (val) => validators.required(val, 'La fecha de vencimiento es obligatoria'),
        (val) => {
          if (!val) return null
          const selectedDate = new Date(val)
          const today = new Date()
          today.setHours(0, 0, 0, 0)
          if (selectedDate <= today) return 'La fecha de vencimiento debe ser en el futuro'
          
          const maxExpDate = calculateMaxLicenseExpDate(formData.value.birth_date)
          if (maxExpDate) {
            const maxDate = new Date(maxExpDate)
            if (selectedDate > maxDate) {
              const age = calculateAge(formData.value.birth_date)
              const years = age < 60 ? 3 : 1
              return `Para una persona de ${age} años, la licencia vence máximo ${years} año(s) desde hoy`
            }
          }
          return null
        }
      ],
      address_driver: [
        (val) => {
          if (val && val.length > 500) return 'La dirección no puede exceder 500 caracteres'
          return null
        }
      ]
    }

    return runValidation(formData.value, rules)
  }

  return {
    errors,
    resetErrors,
    validateNameField,
    validateCedulaField,
    validatePhoneField,
    validateEmailField,
    validateLicenseExpField,
    validateBirthdateField,
    validateForm
  }
}
