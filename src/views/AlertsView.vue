<template>
  <div class="alerts-section">
    <div class="section-header">
      <div class="alerts-stats">
        <div class="stat-card critical">
          <h3>Críticas</h3>
          <span>{{ criticalAlerts }}</span>
        </div>
        <div class="stat-card warning">
          <h3>Advertencias</h3>
          <span>{{ warningAlerts }}</span>
        </div>
        <div class="stat-card info">
          <h3>Informativas</h3>
          <span>{{ infoAlerts }}</span>
        </div>
      </div>
    </div>

    <div class="alerts-list">
      <div
        v-for="alert in alerts"
        :key="alert.id"
        class="alert-item"
        :class="alert.type"
      >
        <div class="alert-icon">{{ alert.icon }}</div>
        <div class="alert-content">
          <h4>{{ alert.title }}</h4>
          <p>{{ alert.message }}</p>
          <span class="alert-time">{{ alert.time }}</span>
        </div>
        <div class="alert-actions">
          <button class="btn-small primary" @click="handleAlertAction(alert)">Ver</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'

// Estado local
const alerts = ref([
  {
    id: 1,
    type: 'critical',
    icon: '⚠️',
    title: 'Bus ABC-123 fuera de ruta',
    message: 'El vehículo se encuentra fuera del trazado establecido',
    time: 'Hace 15 minutos',
    action: 'view'
  },
  {
    id: 2,
    type: 'warning',
    icon: '🔧',
    title: 'Mantenimiento preventivo pendiente',
    message: 'Bus DEF-456 requiere revisión programada',
    time: 'Hace 2 horas',
    action: 'schedule'
  },
  {
    id: 3,
    type: 'info',
    icon: 'ℹ️',
    title: 'Nuevo conductor registrado',
    message: 'Juan Pérez se registró exitosamente en el sistema',
    time: 'Hace 4 horas',
    action: 'view'
  }
])

// Computed properties
const criticalAlerts = computed(() => alerts.value.filter(a => a.type === 'critical').length)
const warningAlerts = computed(() => alerts.value.filter(a => a.type === 'warning').length)
const infoAlerts = computed(() => alerts.value.filter(a => a.type === 'info').length)

// Métodos
const handleAlertAction = (alert) => {
  console.log('Handling alert action:', alert)
  // Implementar acciones específicas según el tipo de alerta
}
</script>

<style scoped>
.alerts-section {
  padding: 0;
}

.section-header {
  margin-bottom: 24px;
}

.alerts-stats {
  display: flex;
  gap: 16px;
}

.stat-card {
  text-align: center;
  background: #f8fafc;
  padding: 16px;
  border-radius: 8px;
  min-width: 100px;
}

.stat-card h3 {
  font-size: 12px;
  color: #64748b;
  margin: 0 0 8px 0;
  text-transform: uppercase;
  font-weight: 500;
}

.stat-card span {
  font-size: 24px;
  font-weight: 700;
  color: #667eea;
}

.stat-card.critical {
  border-left: 4px solid #ef4444;
}

.stat-card.warning {
  border-left: 4px solid #f59e0b;
}

.stat-card.info {
  border-left: 4px solid #3b82f6;
}

.alerts-list {
  display: flex;
  flex-direction: column;
  gap: 16px;
  margin-top: 20px;
}

.alert-item {
  display: flex;
  align-items: flex-start;
  gap: 16px;
  background: white;
  border-radius: 12px;
  border: 1px solid #e2e8f0;
  padding: 20px;
  transition: all 0.3s ease;
}

.alert-item:hover {
  transform: translateY(-1px);
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
}

.alert-item.critical {
  border-left: 4px solid #ef4444;
  background: rgba(239, 68, 68, 0.02);
}

.alert-item.warning {
  border-left: 4px solid #f59e0b;
  background: rgba(245, 158, 11, 0.02);
}

.alert-item.info {
  border-left: 4px solid #3b82f6;
  background: rgba(59, 130, 246, 0.02);
}

.alert-icon {
  font-size: 24px;
  flex-shrink: 0;
}

.alert-content {
  flex: 1;
}

.alert-content h4 {
  margin: 0 0 8px 0;
  color: #1e293b;
  font-weight: 600;
  font-size: 16px;
}

.alert-content p {
  margin: 0 0 8px 0;
  color: #64748b;
  font-size: 14px;
  line-height: 1.5;
}

.alert-time {
  font-size: 12px;
  color: #94a3b8;
  font-style: italic;
}

.alert-actions {
  flex-shrink: 0;
}

/* Responsive */
@media (max-width: 768px) {
  .alerts-stats {
    flex-wrap: wrap;
    justify-content: center;
  }

  .alert-item {
    flex-direction: column;
    text-align: center;
  }

  .alert-actions {
    align-self: stretch;
  }
}
</style>