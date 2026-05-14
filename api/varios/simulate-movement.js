/**
 * Script para simular movimiento de buses en las rutas
 * Actualiza el progress_percentage de cada turno activo
 */

import pool from './config/database.js';
import { io } from 'socket.io-client';


// Cambia la URL si tu WebSocket está en otro host/puerto
const WS_URL = 'http://localhost:3001';

const socket = io(WS_URL, {
    transports: ['websocket'],
    reconnection: true,
});

// 🛑 PLACAS A EXCLUIR DE LA SIMULACIÓN
// Agrega aquí la placa del bus que estás usando en la App del Conductor (ej: 'BUS-001')
const EXCLUDED_PLATES = ['AMB-011', 'RMC315'];

function interpolatePoint(path, progress) {
    if (!path || path.length === 0) return null;
    if (progress <= 0) return [path[0][1], path[0][0]];
    if (progress >= 100) return [path[path.length - 1][1], path[path.length - 1][0]];

    const total = path.length - 1;
    const idx = Math.floor((progress / 100) * total);
    const frac = ((progress / 100) * total) - idx;

    if (idx >= total) return [path[total][1], path[total][0]];

    const [lng1, lat1] = path[idx];
    const [lng2, lat2] = path[idx + 1];

    const lat = lat1 + (lat2 - lat1) * frac;
    const lng = lng1 + (lng2 - lng1) * frac;

    return [lat, lng];
}

async function simulateBusMovement() {
    console.log('🚌 Simulador de movimiento de buses iniciado...\n');
    console.log('   Presiona Ctrl+C para detener\n');
    
const updateProgress = async () => {
    try {
        // Obtener todos los turnos activos y el path en GeoJSON
        const result = await pool.query(`
            SELECT s.id_shift, s.plate_number, s.progress_percentage, s.trips_completed, s.id_route, ST_AsGeoJSON(r.path_route) AS path_route
            FROM tab_active_shifts s
            JOIN tab_routes r ON s.id_route = r.id_route
        `);

        for (const shift of result.rows) {
            // Si el bus está en la lista de excluidos (bus real), saltar simulación
            if (EXCLUDED_PLATES.includes(shift.plate_number)) continue;

            // Parsear el path_route (GeoJSON)
            let path = [];
            try {
                const geo = JSON.parse(shift.path_route);
                path = geo.coordinates || [];
            } catch (e) {
                console.error(`❌ Error parseando path_route para ruta ${shift.id_route}`);
                continue;
            }

            // Incrementar progreso en 1% por actualización (más suave)
            let newProgress = shift.progress_percentage + 1;
            let newTrips = shift.trips_completed;

            // Si llegó al 100%, completar viaje y reiniciar
            if (newProgress >= 100) {
                newProgress = 0;
                newTrips += 1;
                console.log(`🎉 Bus ${shift.plate_number} completó viaje #${newTrips}!`);
            }

            // Redondear a entero (la columna es INTEGER)
            newProgress = Math.round(newProgress);

            // Calcular posición GPS simulada
            const pos = interpolatePoint(path, newProgress);
            if (!pos) continue;

            // Actualizar en la base de datos
            await pool.query(`
                UPDATE tab_active_shifts 
                SET progress_percentage = $1, trips_completed = $2
                WHERE id_shift = $3
            `, [newProgress, newTrips, shift.id_shift]);

            // Corrección de coordenadas para Bucaramanga (Lat ~7, Lng ~-73)
            // interpolatePoint devuelve [Y, X] del path.
            // Si la BD tiene X=Lat, Y=Lng (invertido), devuelve [Lng, Lat].
            // Si la BD tiene X=Lng, Y=Lat (estándar), devuelve [Lat, Lng].
            let lat = pos[0];
            let lng = pos[1];

            // Si lat parece ser una longitud (ej: -73) y lng una latitud (ej: 7), intercambiamos
            if (lat < -30 && lng > -30) {
                lat = pos[1];
                lng = pos[0];
            }

            // Enviar posición por WebSocket
            socket.emit('bus-location', {
                plateNumber: shift.plate_number,
                plate: shift.plate_number,
                routeId: shift.id_route,
                lat: lat,
                lng: lng,
                speed: 30,
                simulated: true
            });

            console.log(`   🚌 ${shift.plate_number}: ${shift.progress_percentage}% → ${newProgress}% | Pos: [${pos[0].toFixed(5)}, ${pos[1].toFixed(5)}]`);
        }

        console.log(`\n   ⏱️  ${new Date().toLocaleTimeString()} - ${result.rows.length} buses actualizados\n`);

    } catch (error) {
        console.error('❌ Error actualizando progreso:', error.message);
    }
};
    
    // Actualizar inmediatamente
    await updateProgress();
    
    // Luego actualizar cada 2 segundos (más frecuente pero con menos incremento)
    const interval = setInterval(updateProgress, 2000);
    
    // Manejar Ctrl+C
    process.on('SIGINT', async () => {
        console.log('\n\n👋 Deteniendo simulador...');
        clearInterval(interval);
        await pool.end();
        process.exit(0);
    });
}

simulateBusMovement();
