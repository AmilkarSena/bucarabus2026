import jwt from 'jsonwebtoken'

if (!process.env.JWT_SECRET) {
  throw new Error('JWT_SECRET is required')
}

const SECRET_KEY = process.env.JWT_SECRET

/**
 * Middleware para verificar token JWT
 * Valida que el usuario está autenticado
 */
export function verifyToken(req, res, next) {
  try {
    const token = req.headers.authorization?.split(' ')[1] // Bearer TOKEN

    if (!token) {
      return res.status(401).json({
        success: false,
        message: 'No hay token de autenticación',
        error_code: 'NO_TOKEN'
      })
    }

    const decoded = jwt.verify(token, SECRET_KEY)
    req.user = decoded // { id_user, email, role }

    console.log(`✅ Token válido - Usuario: ${req.user.email}`)
    next()
  } catch (error) {
    console.error('❌ Token inválido:', error.message)

    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({
        success: false,
        message: 'Token expirado',
        error_code: 'TOKEN_EXPIRED'
      })
    }

    return res.status(401).json({
      success: false,
      message: 'Token inválido',
      error_code: 'INVALID_TOKEN',
      error: error.message
    })
  }
}

/**
 * Middleware para verificar que el usuario es admin
 * Solo admins pueden hacer operaciones sensibles
 */
export function verifyAdmin(req, res, next) {
  // Primero verifica que hay token
  verifyToken(req, res, () => {
    const isAdmin = req.user.id_role === 1 ||
                   (Array.isArray(req.user.roles) && req.user.roles.some(r => r.id_role === 1))

    console.log(`🔐 verifyAdmin - Usuario: ${req.user.email}, id_role: ${req.user.id_role}, roles: ${JSON.stringify(req.user.roles)}, isAdmin: ${isAdmin}`)

    if (!isAdmin) {
      return res.status(403).json({
        success: false,
        message: 'No tienes permisos de administrador',
        error_code: 'FORBIDDEN_ADMIN'
      })
    }
    next()
  })
}

/**
 * Middleware para verificar que el usuario solo accede sus propios datos
 * O es admin
 */
export function verifySelfOrAdmin(req, res, next) {
  verifyToken(req, res, () => {
    const userId = parseInt(req.params.id)
    const currentUserId = req.user.id_user

    // Solo puede acceder sus propios datos o si es admin
    const isAdmin = req.user.id_role === 1 ||
                     (Array.isArray(req.user.roles) && req.user.roles.some(r => r.id_role === 1))

    if (userId !== currentUserId && !isAdmin) {
      return res.status(403).json({
        success: false,
        message: 'No tienes permiso para acceder a estos datos',
        error_code: 'FORBIDDEN_SELF'
      })
    }

    next()
  })
}

/**
 * Middleware para verificar si el usuario tiene un permiso específico (RBAC)
 * Evalúa los permisos cargados en el JWT y soporta comodines (ej: MODULE_*)
 * @param {string} requiredCode - Código del permiso requerido (ej: 'CREATE_BUSES')
 */
export function requirePermission(requiredCode) {
  return (req, res, next) => {
    // Primero verificamos el token
    verifyToken(req, res, () => {
      // Si no tiene arreglo de permisos, se le niega el acceso
      const permissions = req.user.permissions || [];
      
      console.log(`🔐 requirePermission - Requerido: ${requiredCode}, Usuario: ${req.user.email}, Permisos: ${permissions.length}`);

      // 1. Verificamos si tiene el permiso exacto
      const hasExactPermission = permissions.includes(requiredCode);

      // 2. Verificamos si tiene permisos absolutos (para escalabilidad futura, aunque el árbol ya se resuelve solo)
      const hasWildcard = permissions.includes('*') || permissions.includes('ALL_PERMISSIONS');

      if (hasExactPermission || hasWildcard) {
        return next();
      }

      // Si es SuperAdmin (id_role = 1), por diseño actual también le damos paso
      // (Aunque el árbol ya debería darle todos los permisos si corriste los seeds)
      const isAdmin = req.user.id_role === 1 || (Array.isArray(req.user.roles) && req.user.roles.some(r => r.id_role === 1));
      if (isAdmin) {
        return next();
      }

      return res.status(403).json({
        success: false,
        message: 'No tienes permisos suficientes para realizar esta acción',
        required_permission: requiredCode,
        error_code: 'FORBIDDEN_PERMISSION'
      });
    });
  };
}

export default {
  verifyToken,
  verifyAdmin,
  verifySelfOrAdmin,
  requirePermission
}
