import pool from './config/database.js'

async function testDatabase() {
  console.log('🔍 Verificando base de datos...\n')
  
  try {
    // 1. Verificar conexión
    console.log('1️⃣ Probando conexión...')
    const connectionTest = await pool.query('SELECT NOW()')
    console.log('✅ Conexión exitosa:', connectionTest.rows[0].now)
    
    // 2. Verificar si existe la tabla tab_routes
    console.log('\n2️⃣ Verificando tabla tab_routes...')
    const tableCheck = await pool.query(`
      SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_name = 'tab_routes'
      )
    `)
    console.log('✅ Tabla tab_routes existe:', tableCheck.rows[0].exists)
    
    // 3. Verificar estructura de la tabla
    console.log('\n3️⃣ Verificando columnas de tab_routes...')
    const columnsCheck = await pool.query(`
      SELECT column_name, data_type, udt_name
      FROM information_schema.columns 
      WHERE table_name = 'tab_routes'
      ORDER BY ordinal_position
    `)
    console.log('📋 Columnas encontradas:')
    columnsCheck.rows.forEach(col => {
      console.log(`   - ${col.column_name}: ${col.data_type} (${col.udt_name})`)
    })
    
    // 4. Verificar PostGIS
    console.log('\n4️⃣ Verificando extensión PostGIS...')
    const postgisCheck = await pool.query(`
      SELECT EXISTS (
        SELECT FROM pg_extension WHERE extname = 'postgis'
      )
    `)
    console.log('✅ PostGIS instalado:', postgisCheck.rows[0].exists)
    
    // 5. Contar rutas existentes
    console.log('\n5️⃣ Contando rutas en la tabla...')
    const countResult = await pool.query('SELECT COUNT(*) FROM tab_routes')
    console.log('📊 Total de rutas:', countResult.rows[0].count)
    
    // 6. Mostrar rutas existentes
    if (parseInt(countResult.rows[0].count) > 0) {
      console.log('\n6️⃣ Rutas existentes:')
      const routesResult = await pool.query(`
        SELECT 
          id_route,
          name_route,
          descrip_route,
          color_route,
          status_route,
          ST_AsText(path_route) as path_text,
          ST_NumPoints(path_route) as num_points
        FROM tab_routes
        ORDER BY id_route
        LIMIT 10
      `)
      
      routesResult.rows.forEach(route => {
        console.log(`\n   📍 Ruta ${route.id_route}:`)
        console.log(`      Nombre: ${route.name_route}`)
        console.log(`      Descripción: ${route.descrip_route || 'N/A'}`)
        console.log(`      Color: ${route.color_route}`)
        console.log(`      Estado: ${route.status_route}`)
        console.log(`      Puntos: ${route.num_points}`)
        console.log(`      Path: ${route.path_text?.substring(0, 100)}...`)
      })
    }
    
    console.log('\n✅ Verificación completada exitosamente')
    
  } catch (error) {
    console.error('\n❌ Error en verificación:', error.message)
    console.error('Detalles:', error)
  } finally {
    await pool.end()
    process.exit(0)
  }
}

testDatabase()
