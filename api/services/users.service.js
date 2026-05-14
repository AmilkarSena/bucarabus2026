import pool from '../config/database.js'
import bcrypt from 'bcrypt'

const SALT_ROUNDS = 10 //RONDAS DE SAL PARA BCRYPT SE USA PARA AUMENTAR LA SEGURIDAD DE LOS HASH DE CONTRASEÑAS. UN VALOR DE 10 ES UN BUEN EQUILIBRIO ENTRE SEGURIDAD Y RENDIMIENTO.

/**
 * Servicio para gestión de usuarios
 * Conecta con las funciones almacenadas: fun_create_user, fun_update_user
 */

/**
 * Validar nombre completo
 * @param {string} name - Nombre a validar
 * @returns {string|null} - Mensaje de error o null si es válido
 */
function validateName(name) {
  if (!name) {
    return 'El nombre es requerido'
  }

  // Trim automático
  const trimmedName = name.trim()

  // Validar longitud
  if (trimmedName.length < 3) {
    return 'El nombre debe tener al menos 3 caracteres'
  }
  if (trimmedName.length > 100) {
    return 'El nombre no puede exceder 100 caracteres'
  }

  // Validar que solo contenga letras, espacios, acentos, guiones y apóstrofes
  const nameRegex = /^[a-záéíóúñüA-ZÁÉÍÓÚÑÜ\s'\-]+$/
  if (!nameRegex.test(trimmedName)) {
    return 'El nombre solo puede contener letras, espacios, guiones y apóstrofes'
  }

  // Validar que no haya espacios múltiples
  if (/\s{2,}/.test(trimmedName)) {
    return 'El nombre no puede contener espacios múltiples'
  }

  return null
}

/**
 * Validar email
 * @param {string} email - Email a validar
 * @returns {string|null} - Mensaje de error o null si es válido
 */
function validateEmail(email) {
  if (!email) {
    return 'El email es requerido'
  }

  // Trim automático
  const trimmedEmail = email.trim()

  // Validar longitud
  if (trimmedEmail.length > 255) {
    return 'El email no puede exceder 255 caracteres'
  }

  // Validar formato de email
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
  if (!emailRegex.test(trimmedEmail)) {
    return 'El email no es válido (ej: usuario@ejemplo.com)'
  }

  // Validar que no haya caracteres especiales prohibidos
  if (/[<>()\[\]\\,;:\s"]/g.test(trimmedEmail)) {
    return 'El email contiene caracteres no permitidos'
  }

  return null
}

/**
 * Validar contraseña
 * @param {string} password - Contraseña a validar
 * @returns {string|null} - Mensaje de error o null si es válido
 */
function validatePassword(password) {
  if (!password) {
    return 'La contraseña es requerida'
  }

  // Validar longitud
  if (password.length < 8) {
    return 'La contraseña debe tener al menos 8 caracteres'
  }
  if (password.length > 128) {
    return 'La contraseña no puede exceder 128 caracteres'
  }

  // Validar que contenga al menos una mayúscula
  if (!/[A-Z]/.test(password)) {
    return 'La contraseña debe contener al menos una LETRA MAYÚSCULA'
  }

  // Validar que contenga al menos una minúscula
  if (!/[a-z]/.test(password)) {
    return 'La contraseña debe contener al menos una letra minúscula'
  }

  // Validar que contenga al menos un número
  if (!/[0-9]/.test(password)) {
    return 'La contraseña debe contener al menos un NÚMERO (0-9)'
  }

  return null
}

/**
 * Obtener todos los usuarios (con sus roles)
 * @param {Object} filters - Filtros opcionales
 * @param {number} filters.role - ID del rol para filtrar
 * @param {boolean} filters.active - Estado activo/inactivo
 * @returns {Promise<Object>} - { success, data, message }
 */
async function getAllUsers(filters = {}) {
  try {
    const conditions = [];
    const params = [];

    // 1. Construimos los filtros dinámicos primero
    if (filters.role) {
      params.push(filters.role);
      conditions.push(`EXISTS (
        SELECT 1 FROM tab_user_roles ur_sub 
        WHERE ur_sub.id_user = u.id_user 
        AND ur_sub.id_role = $${params.length} 
        AND ur_sub.is_active = true
      )`);
    }

    if (filters.active !== undefined) {
      params.push(filters.active);
      conditions.push(`u.is_active = $${params.length}`);
    }

    let whereClause = '';
    if (conditions.length > 0) {
      whereClause = ' WHERE ' + conditions.join(' AND ');
    }

    // 2. Consulta ultra-rápida solo para contar el total real
    const countQuery = `SELECT COUNT(u.id_user)::INTEGER as total FROM tab_users u` + whereClause;
    const countResult = await pool.query(countQuery, params);
    const totalRecords = countResult.rows[0].total;

    // 3. Matemáticas de la Paginación
    const limit = parseInt(filters.limit) || 50;
    const page = parseInt(filters.page) || 1;
    const offset = (page - 1) * limit;
    
    // Math.ceil redondea hacia arriba (ej: 51 registros / 50 límite = 1.02 -> 2 páginas)
    const totalPages = Math.ceil(totalRecords / limit); 

    // 4. La consulta principal con el JSON anidado
    let mainQuery = `
      SELECT 
        u.id_user,
        u.email_user,
        u.full_name,
        u.is_active,
        json_agg(
          json_build_object(
            'id_role', ur.id_role,
            'role_name', r.role_name,
            'assigned_at', ur.assigned_at
          ) ORDER BY ur.id_role
        ) FILTER (WHERE ur.id_role IS NOT NULL) as roles
      FROM tab_users u
      LEFT JOIN tab_user_roles ur ON u.id_user = ur.id_user AND ur.is_active = true
      LEFT JOIN tab_roles r ON ur.id_role = r.id_role
    ` + whereClause + ` GROUP BY u.id_user ORDER BY u.id_user`;

    // Clonamos los parámetros y añadimos límite y offset al final
    const queryParams = [...params, limit, offset];
    mainQuery += ` LIMIT $${queryParams.length - 1} OFFSET $${queryParams.length}`;

    // Ejecutamos la consulta principal
    const result = await pool.query(mainQuery, queryParams);

    // 5. Retornamos todo organizado para el frontend
    return {
      success: true,
      data: result.rows,
      pagination: {
        total_records: totalRecords,
        total_pages: totalPages,
        current_page: page,
        limit: limit
      }
    };

  } catch (error) {
    console.error('Error en getAllUsers:', error);
    return {
      success: false,
      message: 'Error al obtener usuarios',
      error: error.message
    };
  }
}

/**
 * Obtener usuario por ID (con sus roles)
 * @param {number} userId - ID del usuario
 * @returns {Promise<Object>} - { success, data, message }
 */
async function getUserById(userId) {
  try {
    const query = `
      SELECT 
        u.id_user,
        u.email_user,
        u.full_name,
        u.is_active,
        json_agg(
          json_build_object(
            'id_role', ur.id_role,
            'role_name', r.role_name,
            'assigned_at', ur.assigned_at
          ) ORDER BY ur.id_role
        ) FILTER (WHERE ur.id_role IS NOT NULL) as roles
      FROM tab_users u
      LEFT JOIN tab_user_roles ur ON u.id_user = ur.id_user AND ur.is_active = true
      LEFT JOIN tab_roles r ON ur.id_role = r.id_role
      WHERE u.id_user = $1
      GROUP BY u.id_user
    `

    const result = await pool.query(query, [userId])

    if (result.rows.length === 0) {
      return {
        success: false,
        message: `Usuario con ID ${userId} no encontrado`
      }
    }

    return {
      success: true,
      data: result.rows[0]
    }
  } catch (error) {
    console.error('Error en getUserById:', error)
    return {
      success: false,
      message: 'Error al obtener usuario',
      error: error.message
    }
  }
}

/**
 * Crear nuevo usuario
 * Llama a fun_create_user(wemail_user, wpass_user, wfull_name, wid_role, wuser_create)
 *
 * @param {Object} userData - Datos del usuario
 * @param {string} userData.email - Email único (máx 320 chars)
 * @param {string} userData.password - Contraseña en texto plano
 * @param {string} userData.full_name - Nombre completo (2-100 chars)
 * @param {number} userData.id_role - Rol (1=Administrador, 2=Turnador, 3=Conductor)
 * @param {number} userData.user_create - ID del usuario que crea (default: 1)
 * @returns {Promise<Object>} - { success, data, message, error_code }
 */
async function createUser(userData) {
  try {
    const { email, password, full_name, id_role, user_create = 1 } = userData

    const emailError = validateEmail(email)
    if (emailError) return { success: false, message: emailError }

    const nameError = validateName(full_name)
    if (nameError) return { success: false, message: nameError }

    const passwordError = validatePassword(password)
    if (passwordError) return { success: false, message: passwordError }

    if (!id_role) {
      return { success: false, message: 'El rol es requerido' }
    }
// Hashear contraseña con bcrypt
    const passwordHash = await bcrypt.hash(password, SALT_ROUNDS)

// Llamar a la función almacenada para crear el usuario
    const { rows } = await pool.query(
      'SELECT success, msg, error_code, id_user FROM fun_create_user($1, $2, $3, $4, $5)',
      [email, passwordHash, full_name, id_role, user_create]
    )

    const result = rows[0]

    if (!result.success) {
      return { success: false, message: result.msg, error_code: result.error_code }
    }

    return {
      success: true,
      data: { id_user: result.id_user },
      message: result.msg
    }
  } catch (error) {
    console.error('Error en createUser:', error)
    return {
      success: false,
      message: 'Error al crear usuario',
      error: error.message
    }
  }
}

/**
 * Actualizar usuario (nombre y/o email)
 * Llama a fun_update_user(wid_user, wfull_name, wemail_user)
 *
 * @param {number} userId - ID del usuario
 * @param {Object} updates - Campos a actualizar (al menos uno requerido)
 * @param {string} [updates.full_name]  - Nuevo nombre completo
 * @param {string} [updates.email_user] - Nuevo email
 * @returns {Promise<Object>} - { success, data, message, error_code }
 */
async function updateUser(userId, updates) {
  try {
    const { full_name = null, email_user = null } = updates

    if (!full_name && !email_user) {
      return {
        success: false,
        message: 'Debe proporcionar al menos un campo para actualizar (full_name o email_user)'
      }
    }

    if (full_name) {
      const nameError = validateName(full_name)
      if (nameError) return { success: false, message: nameError }
    }

    if (email_user) {
      const emailError = validateEmail(email_user)
      if (emailError) return { success: false, message: emailError }
    }

    const { rows } = await pool.query(
      'SELECT success, msg, error_code FROM fun_update_user($1, $2, $3)',
      [userId, full_name || null, email_user || null]
    )

    const result = rows[0]

    if (!result.success) {
      return { success: false, message: result.msg, error_code: result.error_code }
    }

    return {
      success: true,
      message: result.msg
    }
  } catch (error) {
    console.error('Error en updateUser:', error)
    return {
      success: false,
      message: 'Error al actualizar usuario',
      error: error.message
    }
  }
}

/**
 * Cambiar contraseña de usuario
 * @param {number} userId - ID del usuario
 * @param {string} newPassword - Nueva contraseña en texto plano
 * @returns {Promise<Object>} - { success, message }
 */
async function changePassword(userId, newPassword) {
  try {
    // Validar contraseña con la función robusta
    const passwordError = validatePassword(newPassword)
    if (passwordError) {
      return {
        success: false,
        message: passwordError
      }
    }

    // Verificar que el usuario existe
    const userExists = await pool.query(
      'SELECT id_user FROM tab_users WHERE id_user = $1',
      [userId]
    )

    if (userExists.rows.length === 0) {
      return {
        success: false,
        message: `Usuario con ID ${userId} no encontrado`
      }
    }

    // Hashear nueva contraseña
    const password_hash = await bcrypt.hash(newPassword, SALT_ROUNDS)

    // Actualizar contraseña
    await pool.query(
      'UPDATE tab_users SET pass_user = $1 WHERE id_user = $2',
      [password_hash, userId]
    )

    return {
      success: true,
      message: 'Contraseña actualizada exitosamente'
    }
  } catch (error) {
    console.error('Error en changePassword:', error)
    return {
      success: false,
      message: 'Error al cambiar contraseña',
      error: error.message
    }
  }
}

/**
 * Activar/Desactivar usuario
 * @param {number} userId - ID del usuario
 * @param {boolean} isActive - Estado activo (true/false)
 * @returns {Promise<Object>} - { success, message }
 */
async function toggleUserStatus(userId, isActive) {
  try {
    const result = await pool.query(
      `SELECT success, msg, error_code, new_status
       FROM fun_toggle_user_status($1::SMALLINT, $2::BOOLEAN)`,
      [userId, isActive]
    )

    const { success, msg, error_code, new_status } = result.rows[0]

    if (!success) {
      return {
        success: false,
        message: msg,
        error_code
      }
    }

    return {
      success: true,
      data: { id_user: userId, is_active: new_status },
      message: msg
    }
  } catch (error) {
    console.error('Error en toggleUserStatus:', error)
    return {
      success: false,
      message: 'Error al cambiar estado del usuario',
      error: error.message
    }
  }
}

/**
 * Obtener roles de un usuario
 * @param {number} userId - ID del usuario
 * @returns {Promise<Object>} - { success, data }
 */
async function getUserRoles(userId) {
  try {
    const query = `
      SELECT 
        r.id_role,
        r.role_name,
        ur.assigned_at,
        ur.is_active
      FROM tab_user_roles ur
      JOIN tab_roles r ON ur.id_role = r.id_role
      WHERE ur.id_user = $1 AND ur.is_active = true
      ORDER BY r.id_role
    `

    const result = await pool.query(query, [userId])

    return {
      success: true,
      data: result.rows
    }
  } catch (error) {
    console.error('Error en getUserRoles:', error)
    return {
      success: false,
      message: 'Error al obtener roles del usuario',
      error: error.message
    }
  }
}

/**
 * Asignar rol a usuario
 * @param {number} userId - ID del usuario
 * @param {number} roleId - ID del rol (1=Pasajero, 2=Conductor, 3=Supervisor, 4=Admin)
 * @param {number} assignedBy - ID del usuario que asigna el rol
 * @returns {Promise<Object>} - { success, message }
 */
async function assignRole(userId, roleId, assignedBy = 1) {
  try {
    const result = await pool.query(
      `SELECT success, msg, error_code
       FROM fun_assign_role($1::SMALLINT, $2::SMALLINT, $3::SMALLINT)`,
      [userId, roleId, assignedBy]
    )

    const { success, msg, error_code } = result.rows[0]

    if (!success) {
      return { success: false, message: msg, error_code }
    }

    return { success: true, message: msg }
  } catch (error) {
    console.error('Error en assignRole:', error)
    return {
      success: false,
      message: 'Error al asignar rol',
      error: error.message
    }
  }
}

/**
 * Quitar rol de usuario
 * @param {number} userId - ID del usuario
 * @param {number} roleId - ID del rol a quitar
 * @returns {Promise<Object>} - { success, message }
 */
async function removeRole(userId, roleId) {
  try {
    const result = await pool.query(
      `SELECT success, msg, error_code
       FROM fun_remove_role($1::SMALLINT, $2::SMALLINT)`,
      [userId, roleId]
    )

    const { success, msg, error_code } = result.rows[0]

    if (!success) {
      return { success: false, message: msg, error_code }
    }

    return { success: true, message: msg }
  } catch (error) {
    console.error('Error en removeRole:', error)
    return {
      success: false,
      message: 'Error al quitar rol',
      error: error.message
    }
  }
}

export default {
  getAllUsers,
  getUserById,
  createUser,
  updateUser,
  changePassword,
  toggleUserStatus,
  getUserRoles,
  assignRole,
  removeRole
}
