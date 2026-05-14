import pool from '../config/database.js'
import bcrypt from 'bcrypt'

const email = 'system@bucarabus.com'
const newPassword = 'Admin123'

const hash = await bcrypt.hash(newPassword, 10)
await pool.query('UPDATE tab_users SET pass_user = $1 WHERE email_user = $2', [hash, email])
console.log('✅ Contraseña actualizada para:', email)
console.log('🔑 Nueva contraseña: Admin123')

const verify = await bcrypt.compare(newPassword, hash)
console.log('✅ Verificación bcrypt:', verify)

process.exit(0)
