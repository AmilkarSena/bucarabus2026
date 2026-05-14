/**
 * Colores únicos y determinísticos para marcadores de buses.
 * La misma placa siempre genera el mismo color, independientemente del orden
 * en que aparezcan los buses. Compartido entre App Admin, Conductor y Pasajero.
 */

const PALETTE = [
  '#ef4444', // rojo
  '#f97316', // naranja
  '#eab308', // amarillo
  '#22c55e', // verde
  '#14b8a6', // teal
  '#3b82f6', // azul
  '#8b5cf6', // violeta
  '#ec4899', // rosa
  '#06b6d4', // cian
  '#84cc16', // lima
  '#f59e0b', // ámbar
  '#6366f1', // índigo
]

/**
 * Devuelve un color hexadecimal único para una placa de bus.
 * Misma placa → mismo color siempre (hash determinístico).
 * @param {string} plate - Placa del bus (ej: "JUD345")
 * @returns {string} Color hexadecimal (#rrggbb)
 */
export function getBusColor(plate) {
  if (!plate) return '#667eea'
  const str = String(plate).toUpperCase()
  let hash = 0
  for (let i = 0; i < str.length; i++) {
    hash = (hash * 31 + str.charCodeAt(i)) & 0x7fffffff
  }
  return PALETTE[hash % PALETTE.length]
}
