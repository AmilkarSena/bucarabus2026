<template>
  <div class="type-block">
    <div class="type-header">
      <span class="type-name">{{ type.name_doc }}</span>
      <span v-if="type.is_mandatory" class="badge-mandatory">Obligatorio</span>
    </div>

    <div v-if="records.length === 0" class="no-record">
      ⚠️ Sin documento registrado
    </div>

    <VigencyRow
      v-for="rec in records"
      :key="rec.id_doc + '-' + rec.init_date"
      :number="rec.doc_number"
      :start-date="rec.init_date"
      :end-date="rec.end_date"
      :doc-url="rec.doc_url"
      :vigency-status="rec.vigency_status"
      :days-remaining="rec.days_remaining"
      @edit="$emit('edit', rec)"
    />
  </div>
</template>

<script setup>
import VigencyRow from '../VigencyRow.vue'

defineProps({
  type:    { type: Object, required: true },
  records: { type: Array, required: true }
})

defineEmits(['edit'])
</script>

<style scoped>
.type-block {
  border: 1px solid #e2e8f0;
  border-radius: 10px;
  overflow: hidden;
}

.type-header {
  background: #f8fafc;
  padding: 10px 16px;
  display: flex;
  align-items: center;
  gap: 8px;
  border-bottom: 1px solid #e2e8f0;
}

.type-name {
  font-weight: 600;
  font-size: 14px;
  color: #334155;
}

.badge-mandatory {
  font-size: 10px;
  background: #bae6fd;
  color: #0369a1;
  border-radius: 4px;
  padding: 1px 6px;
  font-weight: 600;
}

.no-record {
  padding: 12px 16px;
  font-size: 13px;
  color: #b45309;
  background: #fffbeb;
}
</style>
