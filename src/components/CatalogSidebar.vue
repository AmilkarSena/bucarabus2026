<template>
  <!-- Lista de catálogos disponibles (navegación lateral) -->
  <aside class="catalog-sidebar card">
    <div class="sidebar-header">
      <h2 class="sidebar-title">Catálogos</h2>
    </div>
    <nav class="sidebar-nav">
      <button
        v-for="cat in catalogs"
        :key="cat.key"
        class="sidebar-item"
        :class="{ active: modelValue === cat.key }"
        @click="$emit('update:modelValue', cat.key)"
      >
        <span class="item-icon">{{ cat.icon }}</span>
        <span class="item-label">{{ cat.title }}</span>
        <span class="item-count">{{ cat.count }}</span>
      </button>
    </nav>
  </aside>
</template>

<script setup>
defineProps({
  /** Clave del catálogo actualmente seleccionado */
  modelValue: { type: String, required: true },
  /**
   * Lista de catálogos a mostrar.
   * Cada ítem: { key, title, icon, count }
   */
  catalogs: { type: Array, required: true }
})

defineEmits(['update:modelValue'])
</script>

<style scoped>
.catalog-sidebar {
  display: flex;
  flex-direction: column;
  min-height: 0;
}

.card {
  background: white;
  border-radius: 12px;
  box-shadow: 0 1px 3px rgba(0,0,0,0.08);
  border: 1px solid #e2e8f0;
  overflow: hidden;
}

.sidebar-header {
  padding: 16px 16px 12px;
  border-bottom: 1px solid #f1f5f9;
}

.sidebar-title {
  margin: 0;
  font-size: 13px;
  font-weight: 600;
  color: #94a3b8;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.sidebar-nav {
  display: flex;
  flex-direction: column;
  padding: 8px;
  gap: 2px;
}

.sidebar-item {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 12px;
  border: none;
  background: transparent;
  border-radius: 8px;
  cursor: pointer;
  text-align: left;
  transition: background 0.15s;
  width: 100%;
}

.sidebar-item:hover { background: #f8fafc; }

.sidebar-item.active {
  background: #eff6ff;
}

.sidebar-item.active .item-label {
  color: #2563eb;
  font-weight: 600;
}

.sidebar-item.active .item-count {
  background: #dbeafe;
  color: #2563eb;
}

.item-icon { font-size: 16px; flex-shrink: 0; }

.item-label {
  flex: 1;
  font-size: 14px;
  color: #374151;
}

.item-count {
  font-size: 11px;
  font-weight: 600;
  background: #f1f5f9;
  color: #64748b;
  padding: 2px 7px;
  border-radius: 10px;
  min-width: 22px;
  text-align: center;
}

/* Responsive */
@media (max-width: 768px) {
  .catalog-sidebar {
    width: 100% !important;
    border: none;
    border-bottom: 1px solid #e2e8f0;
    border-radius: 0;
    background: #f8fafc;
    position: sticky;
    top: 0;
    z-index: 20;
    box-shadow: none;
  }

  .sidebar-header {
    display: none;
  }

  .sidebar-nav {
    flex-direction: row;
    overflow-x: auto;
    padding: 0 10px;
    gap: 0;
    -webkit-overflow-scrolling: touch;
  }

  .sidebar-item {
    flex-direction: row;
    min-width: auto;
    padding: 12px 16px;
    gap: 6px;
    border: none;
    border-bottom: 2px solid transparent;
    background: transparent;
    border-radius: 0;
    white-space: nowrap;
  }

  .item-label {
    font-size: 13px;
    font-weight: 600;
    text-transform: none;
    color: #64748b;
  }

  .item-count {
    position: static;
    font-size: 10px;
    padding: 2px 6px;
    background: #e2e8f0;
    color: #64748b;
  }

  .sidebar-item.active {
    background: transparent;
    border-bottom-color: #2563eb;
  }

  .sidebar-item.active .item-label {
    color: #2563eb;
  }

  .sidebar-item.active .item-count {
    background: #dbeafe;
    color: #2563eb;
  }
}
</style>
