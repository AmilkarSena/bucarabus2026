/**
 * Script para simular turnos activos
 * Asigna buses existentes a rutas existentes
 */

import pool from './config/database.js';

async function seedActiveShifts() {
    console.log('🚌 Iniciando simulación de turnos activos...\n');
    
    try {
        // 1. Obtener buses activos con conductor
        const busesResult = await pool.query(`
            SELECT b.plate_number, b.amb_code, b.id_user, u.full_name AS name_driver
            FROM tab_buses b
            LEFT JOIN tab_driver_details dd ON b.id_user = dd.id_user
            LEFT JOIN tab_users u ON dd.id_user = u.id_user
            WHERE b.is_active = true
            LIMIT 5
        `);
        console.log(`📋 Buses activos encontrados: ${busesResult.rows.length}`);
        
        // 2. Obtener rutas activas
        const routesResult = await pool.query(`
            SELECT id_route, name_route, color_route
            FROM tab_routes
            WHERE status_route = true
            ORDER BY id_route
        `);
        console.log(`📋 Rutas activas encontradas: ${routesResult.rows.length}\n`);
        
        if (busesResult.rows.length === 0) {
            console.log('❌ No hay buses activos disponibles');
            return;
        }
        
        if (routesResult.rows.length === 0) {
            console.log('❌ No hay rutas activas disponibles');
            return;
        }
        
        // 3. Limpiar turnos anteriores (opcional)
        await pool.query('DELETE FROM tab_active_shifts');
        console.log('🧹 Turnos anteriores eliminados');
        
        // 4. Crear turnos de prueba
        const buses = busesResult.rows;
        const routes = routesResult.rows;
        
        const insertedShifts = [];
        
        for (let i = 0; i < buses.length && i < routes.length; i++) {
            const bus = buses[i];
            const route = routes[i % routes.length];
            const progress = Math.floor(Math.random() * 80) + 10; // 10-90%
            const trips = Math.floor(Math.random() * 5); // 0-4 viajes
            
            try {
                const result = await pool.query(`
                    INSERT INTO tab_active_shifts 
                    (plate_number, id_route, progress_percentage, trips_completed)
                    VALUES ($1, $2, $3, $4)
                    RETURNING *
                `, [bus.plate_number, route.id_route, progress, trips]);
                
                insertedShifts.push({
                    bus: bus.amb_code || bus.plate_number,
                    route: route.name_route,
                    driver: bus.name_driver || 'Sin conductor',
                    progress: `${progress}%`,
                    trips: trips
                });
                
                console.log(`✅ Turno creado: ${bus.amb_code} → ${route.name_route}`);
            } catch (insertError) {
                console.log(`⚠️ Error insertando turno para ${bus.plate_number}: ${insertError.message}`);
            }
        }
        
        console.log('\n' + '='.repeat(60));
        console.log('📊 RESUMEN DE TURNOS ACTIVOS');
        console.log('='.repeat(60));
        
        console.table(insertedShifts);
        
        // 5. Verificar turnos creados
        const verifyResult = await pool.query(`
            SELECT 
                s.plate_number,
                b.amb_code,
                r.name_route,
                r.color_route,
                u.full_name AS name_driver,
                s.progress_percentage,
                s.trips_completed,
                s.started_at
            FROM tab_active_shifts s
            JOIN tab_buses b ON s.plate_number = b.plate_number
            JOIN tab_routes r ON s.id_route = r.id_route
            LEFT JOIN tab_driver_details dd ON b.id_user = dd.id_user
            LEFT JOIN tab_users u ON dd.id_user = u.id_user
        `);
        
        console.log('\n🎉 Simulación completada!');
        console.log(`   Total turnos activos: ${verifyResult.rows.length}`);
        console.log('\n📡 Ahora puedes ver los buses en el mapa en:');
        console.log('   http://localhost:5173\n');
        
    } catch (error) {
        console.error('❌ Error:', error.message);
        console.error(error.stack);
    } finally {
        await pool.end();
    }
}

seedActiveShifts();
