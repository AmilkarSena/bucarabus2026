import { ref } from 'vue'

/**
 * Composable que provee un motor de validación de formularios agnóstico y reutilizable.
 * 
 * Implementa una arquitectura basada en reglas (rules) que permite:
 * 1. Validación Granular: Validar campos individuales mediante funciones puras que 
 *    retornan un mensaje de error o null.
 * 2. Set de Validadores Estándar: Incluye validadores comunes para obligatoriedad, 
 *    longitud mínima, patrones regex, números positivos y fechas futuras.
 * 3. Gestión de Estado de Errores: Centraliza los mensajes de error en un objeto reactivo 
 *    facilitando su visualización en la UI.
 * 4. Validación de Formulario Completo: Método para validar un objeto de datos completo 
 *    antes de permitir el envío (Submit) al servidor.
 * 
 * @returns {Object} { errors, validators, validateField, validateForm, resetErrors }
 */

export function useFormValidation() {
  const errors = ref({})

  const validators = {
    required: (value, message) => {
      if (!value || (typeof value === 'string' && value.trim() === '')) {
        return message || 'Este campo es obligatorio'
      }
      return null
    },

    minLength: (value, min, message) => {
      if (!value || value.trim().length < min) {
        return message || `Debe tener al menos ${min} caracteres`
      }
      return null
    },

    pattern: (value, regex, message) => {
      if (!regex.test(value)) {
        return message || 'Formato inválido'
      }
      return null
    },

    positiveNumber: (value, message) => {
      if (value <= 0) {
        return message || 'Debe ser un número válido'
      }
      return null
    },

    futureDate: (dateString, message) => {
      const date = new Date(dateString)
      const today = new Date()
      today.setHours(0, 0, 0, 0)
      
      if (date <= today) {
        return message || 'Debe ser una fecha futura'
      }
      return null
    }
  }

  const validateField = (fieldName, value, rules = []) => {
    for (const rule of rules) {
      const error = rule(value)
      // Si la regla devuelve un string, es un mensaje de error
      if (typeof error === 'string') {
        errors.value[fieldName] = error
        return false
      }
    }
    // Si pasa todas las validaciones, limpiamos el error de ese campo
    delete errors.value[fieldName]
    return true
  }

  const validateForm = (formData, validationRules) => {
    errors.value = {}
    let isValid = true

    for (const [fieldName, rules] of Object.entries(validationRules)) {
      const value = formData[fieldName]
      if (!validateField(fieldName, value, rules)) {
        isValid = false
      }
    }

    return isValid
  }

  const resetErrors = () => {
    errors.value = {}
  }

  return {
    errors,
    validators,
    validateField,
    validateForm,
    resetErrors
  }
}
