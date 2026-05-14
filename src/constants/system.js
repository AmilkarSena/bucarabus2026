/**
 * Constantes del Sistema BucaraBus
 * ================================
 * Valores constantes utilizados en toda la aplicación
 */

/**
 * ID del usuario de sistema (usado para creaciones/actualizaciones automáticas)
 * Este ID corresponde al usuario 'system@bucarabus.com' en la base de datos
 * Valor: ID 1 (primer usuario insertado por bd_bucarabus.sql)
 */
export const SYSTEM_USER_ID = 1

/**
 * IDs de roles del sistema
 */
export const ROLES = {
  PASAJERO: 1,
  CONDUCTOR: 2,
  SUPERVISOR: 3,
  ADMINISTRADOR: 4
}

/**
 * Estados de ruta
 */
export const ROUTE_STATUS = {
  ACTIVE: 'active',
  INACTIVE: 'inactive',
  MAINTENANCE: 'maintenance'
}

/**
 * OSRM base URL
 * Para usar servidor local: 'http://localhost:5000'
 * Para usar el servidor público (lento): 'https://router.project-osrm.org'
 */
export const OSRM_BASE_URL = 'https://router.project-osrm.org'
