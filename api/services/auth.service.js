import pool from '../config/database.js'
import bcrypt from 'bcrypt'
import jwt from 'jsonwebtoken'

if (!process.env.JWT_SECRET) {
  throw new Error('JWT_SECRET is required')
}

const SECRET_KEY = process.env.JWT_SECRET
const TOKEN_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '24h' // 24 horas por defecto

class AuthService {
  /**
   * Autenticar usuario con email y contraseña
   * @param {string} email - Email del usuario
   * @param {string} password - Contraseña en texto plano
   * @returns {Promise<Object>} Resultado de autenticación
   */
  async login(email, password) {
    try {
      console.log('🔐 Intentando login:', email)
      
      // 1. Obtener usuario de la base de datos
      const result = await pool.query(
        `SELECT 
          id_user,
          email_user,
          pass_user,
          full_name,
          is_active
        FROM tab_users
        WHERE LOWER(email_user) = LOWER($1)`,
        [email]
      )
      
      if (result.rows.length === 0) {
        console.log('❌ Usuario no encontrado:', email)
        return {
          success: false,
          message: 'Usuario no encontrado',
          error_code: 'USER_NOT_FOUND'
        }
      }
      
      const user = result.rows[0]
      
      // 2. Verificar si el usuario está activo
      if (!user.is_active) {
        console.log('❌ Usuario inactivo:', email)
        return {
          success: false,
          message: 'Usuario desactivado. Contacta al administrador',
          error_code: 'USER_INACTIVE'
        }
      }
      
      // 3. Comparar contraseña con bcrypt
      const passwordMatch = await bcrypt.compare(password, user.pass_user)
      
      if (!passwordMatch) {
        console.log('❌ Contraseña incorrecta para:', email)
        return {
          success: false,
          message: 'Contraseña incorrecta',
          error_code: 'INVALID_PASSWORD'
        }
      }
      
      // 4. Obtener roles del usuario
      const rolesResult = await pool.query(
        `SELECT 
          r.id_role,
          r.role_name,
          r.descrip_role
        FROM tab_user_roles ur
        INNER JOIN tab_roles r ON ur.id_role = r.id_role
        WHERE ur.id_user = $1 
          AND ur.is_active = TRUE
          AND r.is_active = TRUE
        ORDER BY r.id_role DESC`,
        [user.id_user]
      )
      
      // 4.5 Obtener permisos efectivos: (rol - denys personales) + allows personales
      const permissionsResult = await pool.query(
        `-- Permisos heredados del rol, excluyendo denys personales
         SELECT DISTINCT p.code_permission
         FROM tab_user_roles ur
         JOIN tab_role_permissions rp ON ur.id_role = rp.id_role
         JOIN tab_permissions p ON rp.id_permission = p.id_permission
         WHERE ur.id_user = $1
           AND ur.is_active = TRUE
           AND p.is_active = TRUE
           AND NOT EXISTS (
             SELECT 1 FROM tab_user_permissions up
             WHERE up.id_user = $1
               AND up.id_permission = p.id_permission
               AND up.is_granted = FALSE
           )
         UNION
         -- Allows personales (permisos extra que el rol no tiene)
         SELECT p.code_permission
         FROM tab_user_permissions up
         JOIN tab_permissions p ON up.id_permission = p.id_permission
         WHERE up.id_user = $1
           AND up.is_granted = TRUE
           AND p.is_active = TRUE`,
        [user.id_user]
      )
      const permissions = permissionsResult.rows.map(p => p.code_permission)
      
      // 5. Construir datos del usuario (sin pass_user)
      const userData = {
        id_user: user.id_user,
        email: user.email_user,
        full_name: user.full_name,
        is_active: user.is_active,
        roles: rolesResult.rows,
        permissions: permissions // 🆕 Permisos añadidos
      }

      // 6. Generar JWT Token
      const primaryRole = rolesResult.rows[0]?.id_role || 1            // 1 = Administrador, 2 = Conductor, 
      
      const token = jwt.sign(                                       // Genera el token JWT
        {
          id_user: user.id_user,                                   // ID del usuario
          email: user.email_user,                                   // Email del usuario
          full_name: user.full_name,                                // Nombre completo del usuario
          id_role: primaryRole,                                     // Rol principal del usuario
          roles: rolesResult.rows.map(r => ({ id_role: r.id_role, role_name: r.role_name })), // Roles del usuario
          permissions: permissions                                  // 🆕 Permisos para el middleware
        },
        SECRET_KEY,                                               // Clave secreta para firmar el token
        { expiresIn: TOKEN_EXPIRES_IN }                             // Tiempo de expiración del token
      )

      console.log('✅ Login exitoso:', email, '- Roles:', rolesResult.rows.map(r => r.role_name).join(', '))
      
      return {
        success: true,
        message: 'Autenticación exitosa',
        token, // 🆕 Token JWT
        auth: { // 🆕 Datos originales para compatibilidad
          user: userData,
          timestamp: new Date().toISOString(),
          expiresIn: TOKEN_EXPIRES_IN
        },
        data: userData // 🆕 Mantener esto para compatibilidad con código existente
      }
      
    } catch (error) {
      console.error('❌ Error en login:', error)
      return {
        success: false,
        message: 'Error del servidor al autenticar',
        error_code: 'SERVER_ERROR'
      }
    }
  }
  
  /**
   * Obtener datos del usuario por email (sin contraseña)
   * Usado para refrescar sesión cuando uid no está en memoria
   * También genera un nuevo JWT token si se solicita
   * @param {string} email - Email del usuario
   * @param {boolean} generateToken - Si true, genera nuevo JWT token
   * @returns {Promise<Object>} Datos del usuario con roles y opcionalmente token
   */
  async getUserByEmail(email, generateToken = false) {
    try {
      const result = await pool.query(
        `SELECT 
          id_user,
          email_user,
          full_name,
          is_active
        FROM tab_users
        WHERE LOWER(email_user) = LOWER($1) AND is_active = TRUE`,
        [email]
      )

      if (result.rows.length === 0) {
        return { success: false, message: 'Usuario no encontrado' }
      }

      const user = result.rows[0]

      // Obtener roles
      const rolesResult = await pool.query(
        `SELECT r.id_role, r.role_name, r.descrip_role
         FROM tab_user_roles ur
         INNER JOIN tab_roles r ON ur.id_role = r.id_role
         WHERE ur.id_user = $1 AND ur.is_active = TRUE AND r.is_active = TRUE`,
        [user.id_user]
      )

      // Obtener permisos efectivos: (rol - denys personales) + allows personales
      const permissionsResult = await pool.query(
        `-- Permisos heredados del rol, excluyendo denys personales
         SELECT DISTINCT p.code_permission
         FROM tab_user_roles ur
         JOIN tab_role_permissions rp ON ur.id_role = rp.id_role
         JOIN tab_permissions p ON rp.id_permission = p.id_permission
         WHERE ur.id_user = $1
           AND ur.is_active = TRUE
           AND p.is_active = TRUE
           AND NOT EXISTS (
             SELECT 1 FROM tab_user_permissions up
             WHERE up.id_user = $1
               AND up.id_permission = p.id_permission
               AND up.is_granted = FALSE
           )
         UNION
         -- Allows personales (permisos extra que el rol no tiene)
         SELECT p.code_permission
         FROM tab_user_permissions up
         JOIN tab_permissions p ON up.id_permission = p.id_permission
         WHERE up.id_user = $1
           AND up.is_granted = TRUE
           AND p.is_active = TRUE`,
        [user.id_user]
      )
      const permissions = permissionsResult.rows.map(p => p.code_permission)

      const userData = {
        id_user: user.id_user,
        email: user.email_user,
        full_name: user.full_name,
        is_active: user.is_active,
        roles: rolesResult.rows,
        permissions: permissions
      }

      // Si se solicita, generar nuevo token (útil para refresh)
      if (generateToken) {
        const primaryRole = rolesResult.rows[0]?.id_role || 1

        const token = jwt.sign(
          {
            id_user: user.id_user,
            email: user.email_user,
            full_name: user.full_name,
            id_role: primaryRole,
            roles: rolesResult.rows.map(r => ({ id_role: r.id_role, role_name: r.role_name })),
            permissions: permissions
          },
          SECRET_KEY,
          { expiresIn: TOKEN_EXPIRES_IN }
        )

        return {
          success: true,
          token,
          data: userData
        }
      }

      return {
        success: true,
        data: userData
      }
    } catch (error) {
      console.error('Error en getUserByEmail:', error)
      return { success: false, message: 'Error del servidor' }
    }
  }

  /**
   * Verificar si un email existe en la base de datos
   * @param {string} email - Email a verificar
   * @returns {Promise<boolean>} true si existe, false si no
   */
  async emailExists(email) {
    try {
      const result = await pool.query(
        `SELECT EXISTS(SELECT 1 FROM tab_users WHERE LOWER(email_user) = LOWER($1))`,
        [email]
      )
      return result.rows[0].exists
    } catch (error) {
      console.error('Error verificando email:', error)
      return false
    }
  }
}

export default new AuthService()
