import { jest } from '@jest/globals'

// Mock del pool de la base de datos antes de importar el servicio
jest.unstable_mockModule('../config/database.js', () => ({
  default: {
    query: jest.fn()
  }
}))

const { default: userService } = await import('./users.service.js')

describe('Users Service', () => {
  it('should validate invalid email formats', async () => {
    const result = await userService.createUser({ email: 'invalid-email' })
    expect(result.success).toBe(false)
    expect(result.message).toBe('El email no es válido (ej: usuario@ejemplo.com)')
  })
})
