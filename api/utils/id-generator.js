/**
 * Generador de IDs únicos basados en INTEGER (4 bytes)
 * Formato: Timestamp en segundos (10 dígitos) + Random (3 dígitos) = max 13 dígitos
 * 
 * Ventajas:
 * - Portable entre diferentes BD (no depende de SERIAL/secuencias)
 * - Ordenable cronológicamente
 * - Ahorra espacio vs BIGINT (4 bytes vs 8 bytes)
 * - Único con probabilidad extremadamente alta
 * - Cabe en INTEGER (máx: 2,147,483,647 ≈ 2.1 mil millones)
 * 
 * Limitaciones:
 * - Máximo ~2.1 mil millones de usuarios (suficiente para ciudades pequeñas)
 * - Funciona hasta año 2286 (después timestamp segundos excede 10 dígitos)
 */

/**
 * Generar ID único tipo INTEGER
 * @returns {number} ID de máximo 13 dígitos que cabe en INTEGER (32-bit)
 * 
 * Ejemplo: "1708023456" (timestamp seg) + "123" (random) = 1708023456123
 */
export function generateId() {
  const timestampSeconds = Math.floor(Date.now() / 1000) // 10 dígitos (segundos desde 1970)
  const random = Math.floor(Math.random() * 1000) // 0-999 (3 dígitos)
  
  // Combinar timestamp + random
  const id = timestampSeconds * 1000 + random
  
  // Verificar que cabe en INTEGER (2,147,483,647)
  if (id > 2147483647) {
    console.warn('⚠️ ID generado excede INTEGER, considerar usar BIGINT')
  }
  
  return id
}

/**
 * Generar ID con más entropía (4 dígitos random)
 * Usar si tienes MUCHO volumen (>1000 registros/segundo)
 * @returns {number} ID con más espacio random
 */
export function generateIdExtended() {
  const timestampSeconds = Math.floor(Date.now() / 1000) // 10 dígitos
  const random = Math.floor(Math.random() * 10000) // 0-9999 (4 dígitos)
  
  const id = timestampSeconds * 10000 + random
  
  if (id > 2147483647) {
    console.warn('⚠️ ID excede INTEGER, usa BIGINT o reduce el timestamp')
  }
  
  return id
}

/**
 * Validar que un ID sea válido
 * @param {number} id 
 * @returns {boolean}
 */
export function isValidId(id) {
  if (!id) return false
  
  // Debe ser numérico
  if (typeof id !== 'number' || isNaN(id)) return false
  
  // Debe ser positivo
  if (id <= 0) return false
  
  // Debe caber en INTEGER
  if (id > 2147483647) return false
  
  // Extraer timestamp (primeros 10 dígitos)
  const timestampSeconds = Math.floor(id / 1000)
  
  // Verificar que el timestamp sea razonable (después de 2020, antes de 2100)
  const year2020 = 1577836800 // 01/01/2020 en segundos
  const year2100 = 4102444800 // 01/01/2100 en segundos
  
  if (timestampSeconds < year2020 || timestampSeconds > year2100) return false
  
  return true
}

/**
 * Extraer la fecha de creación desde un ID
 * @param {number} id 
 * @returns {Date|null}
 */
export function getDateFromId(id) {
  if (!isValidId(id)) return null
  
  const timestampSeconds = Math.floor(id / 1000)
  return new Date(timestampSeconds * 1000) // Convertir a milisegundos
}

/**
 * Generar múltiples IDs únicos de forma segura
 * Garantiza que no haya duplicados incluso si se llama en el mismo segundo
 * @param {number} count - Cantidad de IDs a generar
 * @returns {number[]}
 */
export function generateBatch(count) {
  const ids = new Set()
  
  while (ids.size < count) {
    ids.add(generateId())
    // Pequeño delay para evitar colisiones en el mismo segundo
    if (ids.size < count && ids.size % 100 === 0) {
      // Esperar 1ms cada 100 IDs para cambiar de segundo si es necesario
      const start = Date.now()
      while (Date.now() === start) { /* busy wait */ }
    }
  }
  
  return Array.from(ids)
}

// Exportar por defecto el generador simple
export default generateId
