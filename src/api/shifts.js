/**
 * API Client para Turnos Activos
 */

import apiClient from './client.js';

/**
 * Obtener todos los turnos activos
 */
export async function getActiveShifts() {
    const response = await apiClient.get('/shifts');
    const data = response.data;
    if (!data.success) throw new Error(data.error || 'Error al obtener turnos');
    return data.data;
}

/**
 * Obtener turno activo por placa
 */
export async function getShiftByPlate(plateNumber) {
    const response = await apiClient.get(`/shifts/${plateNumber}`);
    const data = response.data;
    if (!data.success) throw new Error(data.error || 'Error al obtener turno');
    return data.data;
}

/**
 * Iniciar un turno
 */
export async function startShift(shiftData) {
    const response = await apiClient.post('/shifts', shiftData);
    const data = response.data;
    if (!data.success) throw new Error(data.error || 'Error al iniciar turno');
    return data.data;
}

/**
 * Finalizar un turno
 */
export async function endShift(plateNumber) {
    const response = await apiClient.delete(`/shifts/${plateNumber}`);
    const data = response.data;
    if (!data.success) throw new Error(data.error || 'Error al finalizar turno');
    return data.data;
}

/**
 * Obtener buses disponibles (sin turno activo)
 */
export async function getAvailableBuses() {
    const response = await apiClient.get('/shifts/available-buses');
    const data = response.data;
    if (!data.success) throw new Error(data.error || 'Error al obtener buses disponibles');
    return data.data;
}

export default {
    getActiveShifts,
    getShiftByPlate,
    startShift,
    endShift,
    getAvailableBuses
};
