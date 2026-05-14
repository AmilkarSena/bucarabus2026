import { useFormValidation } from './useFormValidation'
import { driverSchema } from '../../shared/validations/driver.schema.js'

export function useDriverValidation(formData, helpers) {
  const { calculateAge, calculateMaxLicenseExpDate } = helpers
  const { errors, resetErrors } = useFormValidation()

  // Helper para limpiar un campo
  const clearFieldError = (field) => {
    errors.value[field] = null
  }

  // Validaciones en tiempo real (on blur) usan partes del schema o lo evalúan completo
  const validateFieldWithZod = (field) => {
    const dataToValidate = { ...formData.value }
    if (dataToValidate.id_eps === '') dataToValidate.id_eps = null
    if (dataToValidate.id_arl === '') dataToValidate.id_arl = null

    const result = driverSchema.safeParse(dataToValidate)
    if (!result.success) {
      // Buscar si este campo falló
      const issues = result.error?.issues || result.error?.errors || []
      const fieldError = issues.find(err => err.path[0] === field)
      if (fieldError) {
        errors.value[field] = fieldError.message
        return false
      }
    }
    clearFieldError(field)
    return true
  }

  const validateNameField = () => validateFieldWithZod('name_driver')
  const validateCedulaField = () => validateFieldWithZod('id_driver')
  const validatePhoneField = () => validateFieldWithZod('phone_driver')
  const validateEmailField = () => validateFieldWithZod('email_driver')

  const validateLicenseExpField = () => {
    const isValidBasic = validateFieldWithZod('license_exp')
    if (!isValidBasic) return

    const val = formData.value.license_exp
    if (!val) return // Zod ya valida required, esto es precaución

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
          clearFieldError('license_exp')
        }
      } else {
        clearFieldError('license_exp')
      }
    }
  }

  const validateBirthdateField = () => {
    const val = formData.value.birth_date
    if (!val) {
      clearFieldError('birth_date')
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
        clearFieldError('birth_date')
        if (formData.value.license_exp) {
          validateLicenseExpField()
        }
      }
    }
  }

  const validateForm = () => {
    // 1. Limpiar errores previos
    resetErrors()
    let isValid = true

    // 2. Validación de Zod (Esquema compartido)
    // Pasamos strings vacíos a null para que Zod no falle en tipos number si el input está limpio
    const dataToValidate = { ...formData.value }
    if (dataToValidate.id_eps === '') dataToValidate.id_eps = null
    if (dataToValidate.id_arl === '') dataToValidate.id_arl = null

    const result = driverSchema.safeParse(dataToValidate)
    
    if (!result.success) {
      isValid = false
      const issues = result.error?.issues || result.error?.errors || []
      issues.forEach(err => {
        const field = err.path[0]
        errors.value[field] = err.message
      })
    }

    // 3. Validaciones de negocio dinámicas (Edades, fechas dinámicas)
    validateBirthdateField()
    if (errors.value.birth_date) isValid = false

    validateLicenseExpField()
    if (errors.value.license_exp) isValid = false

    return isValid
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
