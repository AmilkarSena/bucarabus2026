<template>
  <div class="vigency-row" :class="vigencyStatus">
    <div class="row-info">
      <span class="row-num">{{ number }}</span>
      <span v-if="subtitle" class="subtitle">{{ subtitle }}</span>
      <span class="dates">{{ fmtDate(startDate) }} → {{ fmtDate(endDate) }}</span>
    </div>
    
    <div class="row-right">
      <span class="vigency-tag" :class="'vt-' + vigencyStatus">{{ vigencyLabel }}</span>
      
      <a
        v-if="docUrl"
        :href="docUrl"
        target="_blank"
        rel="noopener"
        class="btn-xs"
        title="Ver documento"
      >📎</a>
      
      <button
        class="btn-xs btn-edit"
        title="Editar / Reemplazar"
        @click="$emit('edit')"
      >✏️</button>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  number:        { type: String, required: true },
  subtitle:      { type: String, default: null },
  startDate:     { type: String, required: true },
  endDate:       { type: String, required: true },
  docUrl:        { type: String, default: null },
  vigencyStatus: { type: String, default: 'active' }, // 'active', 'expiring', 'expired', 'cancelled'
  daysRemaining: { type: Number, default: null }
})

defineEmits(['edit'])

const vigencyLabel = computed(() => {
  if (props.vigencyStatus === 'expired')   return '❌ Vencido'
  if (props.vigencyStatus === 'expiring')  return `⚠️ Vence en ${props.daysRemaining}d`
  if (props.vigencyStatus === 'cancelled') return '⛔ Cancelado'
  return '✅ Vigente'
})

function fmtDate(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString('es-CO', { day: '2-digit', month: 'short', year: 'numeric' })
}
</script>

<style scoped>
.vigency-row {
  padding: 10px 16px;
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 12px;
  border-top: 1px solid #f1f5f9;
  font-size: 13px;
  background: #ffffff;
}

.vigency-row.cancelled { opacity: 0.5; }
.vigency-row.expired   { background: #fff5f5; }
.vigency-row.expiring  { background: #fffbeb; }

.row-info {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.row-num {
  font-weight: 600;
  color: #334155;
  font-size: 13px;
  font-family: monospace;
}

.subtitle {
  color: #64748b;
  font-size: 12px;
}

.dates {
  color: #94a3b8;
  font-size: 11px;
}

.row-right {
  display: flex;
  align-items: center;
  gap: 6px;
  flex-shrink: 0;
}

.vigency-tag {
  font-size: 11px;
  font-weight: 600;
  border-radius: 4px;
  padding: 2px 7px;
  white-space: nowrap;
}

.vt-active    { background: #dcfce7; color: #15803d; }
.vt-expiring  { background: #fef3c7; color: #b45309; }
.vt-expired   { background: #fee2e2; color: #b91c1c; }
.vt-cancelled { background: #f1f5f9; color: #64748b; }

.btn-xs {
  background: none;
  border: 1px solid #e2e8f0;
  border-radius: 6px;
  padding: 3px 8px;
  cursor: pointer;
  font-size: 13px;
  text-decoration: none;
  display: inline-flex;
  align-items: center;
  transition: all 0.2s;
  color: #475569;
}

.btn-xs:hover { background: #f1f5f9; }

.btn-edit { border-color: #93c5fd; }
.btn-edit:hover { background: #eff6ff; }
</style>
