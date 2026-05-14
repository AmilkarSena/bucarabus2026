<template>
  <aside class="compliance-sidebar">
    <div class="sidebar-header">
      <h3 class="sidebar-title">Secciones</h3>
    </div>
    <nav class="sidebar-nav">
      <!-- Opción Seguros -->
      <button
        class="sidebar-item"
        :class="{ active: modelValue === 'insurance' }"
        @click="$emit('update:modelValue', 'insurance')"
      >
        <span class="item-icon">🛡️</span>
        <div class="item-text">
          <span class="item-label">Seguros</span>
          <span class="item-desc">Pólizas y SOAT</span>
        </div>
      </button>

      <!-- Opción Documentos -->
      <button
        class="sidebar-item"
        :class="{ active: modelValue === 'docs' }"
        @click="$emit('update:modelValue', 'docs')"
      >
        <span class="item-icon">📄</span>
        <div class="item-text">
          <span class="item-label">Documentos</span>
          <span class="item-desc">Tránsito y Operación</span>
        </div>
      </button>
    </nav>
  </aside>
</template>

<script setup>
defineProps({
  modelValue: { type: String, required: true } // 'insurance' | 'docs'
})

defineEmits(['update:modelValue'])
</script>

<style scoped>
.compliance-sidebar {
  display: flex;
  flex-direction: column;
  background: #f8fafc;
  border-right: 1px solid #e2e8f0;
}

.sidebar-header {
  padding: 16px;
  border-bottom: 1px solid #e2e8f0;
}

.sidebar-title {
  margin: 0;
  font-size: 13px;
  font-weight: 600;
  color: #64748b;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.sidebar-nav {
  display: flex;
  flex-direction: column;
  padding: 12px;
  gap: 8px;
}

.sidebar-item {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px;
  border: 1px solid transparent;
  background: transparent;
  border-radius: 10px;
  cursor: pointer;
  text-align: left;
  transition: all 0.2s;
  width: 100%;
}

.sidebar-item:hover {
  background: #f1f5f9;
}

.sidebar-item.active {
  background: #ffffff;
  border-color: #cbd5e1;
  box-shadow: 0 2px 4px rgba(0,0,0,0.05);
}

.sidebar-item.active .item-label {
  color: #0f172a;
  font-weight: 600;
}

.item-icon {
  font-size: 20px;
  flex-shrink: 0;
}

.item-text {
  display: flex;
  flex-direction: column;
  gap: 2px;
  flex: 1;
}

.item-label {
  font-size: 14px;
  color: #475569;
  font-weight: 500;
}

.item-desc {
  font-size: 11px;
  color: #94a3b8;
}
</style>
