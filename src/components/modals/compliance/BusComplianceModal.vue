<template>
  <div class="modal-overlay" @click.self="$emit('close')">
    <div class="compliance-panel">
      <!-- Header -->
      <div class="compliance-header">
        <h2>📋 Cumplimiento — <span class="plate-tag">{{ plate }}</span></h2>
        <button class="close-btn" @click="$emit('close')">&times;</button>
      </div>

      <!-- Body: Sidebar + Panel activo -->
      <div class="compliance-body">
        <ComplianceSidebar v-model="activeSection" />

        <div class="compliance-content">
          <InsuranceSection
            v-if="activeSection === 'insurance'"
            :plate="plate"
            @updated="$emit('updated')"
          />
          <TransitDocsSection
            v-if="activeSection === 'docs'"
            :plate="plate"
            @updated="$emit('updated')"
          />
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import ComplianceSidebar from './ComplianceSidebar.vue'
import InsuranceSection from './insurance/InsuranceSection.vue'
import TransitDocsSection from './docs/TransitDocsSection.vue'

const props = defineProps({
  plate: { type: String, required: true },
  initialSection: { type: String, default: 'insurance' }
})

defineEmits(['close', 'updated'])

const activeSection = ref(props.initialSection)
</script>

<style scoped>
.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.55);
  z-index: 10500;
  display: flex;
  justify-content: center;
  align-items: center;
  backdrop-filter: blur(3px);
}

.compliance-panel {
  background: #fff;
  border-radius: 16px;
  width: 95%;
  max-width: 900px;
  max-height: 88vh;
  display: flex;
  flex-direction: column;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.25);
  overflow: hidden;
}

/* Header */
.compliance-header {
  background: linear-gradient(135deg, #1e293b, #334155);
  color: #fff;
  padding: 18px 24px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  flex-shrink: 0;
}

.compliance-header h2 {
  margin: 0;
  font-size: 18px;
  font-weight: 600;
}

.plate-tag {
  background: rgba(255, 255, 255, 0.25);
  border-radius: 6px;
  padding: 2px 8px;
  font-size: 15px;
  font-family: monospace;
}

.close-btn {
  background: none;
  border: none;
  color: #fff;
  font-size: 26px;
  cursor: pointer;
  line-height: 1;
  padding: 0 4px;
}

/* Body */
.compliance-body {
  display: flex;
  flex: 1;
  overflow: hidden;
}

:deep(.compliance-sidebar) {
  width: 220px;
  flex-shrink: 0;
}

.compliance-content {
  flex: 1;
  overflow-y: auto;
  background: #ffffff;
}

@media (max-width: 768px) {
  .compliance-panel {
    max-width: 100%;
    border-radius: 0;
    max-height: 100vh;
  }
  
  .compliance-body {
    flex-direction: column;
  }

  :deep(.compliance-sidebar) {
    width: 100%;
    border-right: none;
    border-bottom: 1px solid #e2e8f0;
  }

  :deep(.sidebar-nav) {
    flex-direction: row;
    overflow-x: auto;
  }

  :deep(.sidebar-item) {
    flex-direction: column;
    text-align: center;
    gap: 4px;
    width: auto;
    min-width: 120px;
  }

  :deep(.item-text) {
    align-items: center;
  }
}
</style>
