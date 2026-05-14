<template>
  <!--
    Panel derecho: muestra el CatalogCard del catálogo activo.
    Solo responsabilidad: renderizar la tabla del catálogo seleccionado
    y delegar los eventos al padre.
  -->
  <div class="catalog-panel">
    <div v-if="!activeCatalog" class="empty-state">
      <span class="empty-icon">👈</span>
      <p>Selecciona un catálogo del panel izquierdo</p>
    </div>

    <CatalogCard
      v-else
      :title="activeCatalog.title"
      :icon="activeCatalog.icon"
      :singular="activeCatalog.singular"
      :items="activeCatalog.items"
      :loading="loading"
      :id-key="activeCatalog.idKey"
      :name-key="activeCatalog.nameKey"
      :extra-key="activeCatalog.extraKey"
      :extra-label="activeCatalog.extraLabel"
      :card-error="cardError"
      :can-create="canCreate"
      :can-edit="canEdit"
      :can-toggle="canToggle"
      @create="$emit('create')"
      @edit="(item) => $emit('edit', item)"
      @toggle="(item) => $emit('toggle', item)"
    />
  </div>
</template>

<script setup>
import CatalogCard from './CatalogCard.vue'

defineProps({
  /** Objeto del catálogo activo con toda la metadata necesaria para CatalogCard */
  activeCatalog: { type: Object, default: null },
  /** Estado de carga del store */
  loading:       { type: Boolean, default: false },
  /** Error a mostrar en la tarjeta (ej: error de toggle) */
  cardError:     { type: String, default: null },
  // Permisos
  canCreate: { type: Boolean, default: false },
  canEdit:   { type: Boolean, default: false },
  canToggle: { type: Boolean, default: false }
})

defineEmits(['create', 'edit', 'toggle'])
</script>

<style scoped>
.catalog-panel {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
}

.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 300px;
  color: #94a3b8;
  background: white;
  border-radius: 12px;
  border: 1px solid #e2e8f0;
  gap: 12px;
}

.empty-icon {
  font-size: 40px;
  opacity: 0.5;
}

.empty-state p {
  margin: 0;
  font-size: 14px;
}
</style>
