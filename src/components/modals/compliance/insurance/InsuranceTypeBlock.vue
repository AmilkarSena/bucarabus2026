<template>
  <div class="type-block">
    <div class="type-header">
      <span class="type-name">{{ type.type_name }}</span>
      <span v-if="type.is_mandatory" class="badge-mandatory">Obligatorio</span>
    </div>

    <div v-if="records.length === 0" class="no-record">
      ⚠️ Sin póliza registrada
    </div>

    <VigencyRow
      v-for="rec in records"
      :key="rec.id_insurance"
      :number="rec.id_insurance"
      :subtitle="rec.insurer_name"
      :start-date="rec.start_date_insu"
      :end-date="rec.end_date_insu"
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
  background: #fde68a;
  color: #92400e;
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
