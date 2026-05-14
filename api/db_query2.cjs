const { Pool } = require('pg');
const pool = new Pool({ user: 'postgres', host: 'localhost', database: 'db_bucarabus', password: 'admin', port: 5432 });
pool.query("SELECT * FROM information_schema.tables WHERE table_schema='public' AND table_name LIKE 'tab_%'").then(res => { console.table(res.rows.map(r => r.table_name)); pool.end(); });
