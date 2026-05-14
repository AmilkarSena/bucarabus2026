import pool from '../config/database.js'
const r = await pool.query("SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename")
console.log(r.rows.map(x => x.tablename).join('\n'))
await pool.end()
