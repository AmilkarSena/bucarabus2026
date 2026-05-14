<template>
  <div class="roles-panel card">
    <h2 class="panel-title">Roles</h2>
    <div v-if="loading" class="loading-state">Cargando roles...</div>
    <ul v-else class="role-list">
      <li 
        v-for="role in roles" 
        :key="role.id_role"
        class="role-item"
        :class="{ active: selectedRoleId === role.id_role }"
        @click="$emit('select-role', role)"
      >
        <div class="role-icon">👤</div>
        <div class="role-info">
          <span class="role-name">{{ role.role_name }}</span>
        </div>
        <span class="arrow">▶</span>
      </li>
    </ul>
  </div>
</template>

<script setup>
defineProps({
  roles: {
    type: Array,
    required: true
  },
  loading: {
    type: Boolean,
    default: false
  },
  selectedRoleId: {
    type: Number,
    default: null
  }
})

defineEmits(['select-role'])
</script>

<style scoped>
.card {
  background: white;
  border-radius: 12px;
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.panel-title {
  font-size: 16px;
  font-weight: 600;
  color: #334155;
  padding: 16px 20px;
  margin: 0;
  border-bottom: 1px solid #e2e8f0;
  background: #f8fafc;
}

.roles-panel {
  width: 320px;
  flex-shrink: 0;
  height: 100%;
}

.role-list {
  list-style: none;
  padding: 0;
  margin: 0;
  overflow-y: auto;
  flex: 1;
}

.role-item {
  display: flex;
  align-items: center;
  padding: 16px 20px;
  cursor: pointer;
  border-bottom: 1px solid #f1f5f9;
  transition: all 0.2s;
}

.role-item:hover {
  background: #f8fafc;
}

.role-item.active {
  background: #eff6ff;
  border-left: 4px solid #3b82f6;
}

.role-icon {
  font-size: 24px;
  background: #e2e8f0;
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  margin-right: 16px;
}

.role-item.active .role-icon {
  background: #bfdbfe;
  color: #1d4ed8;
}

.role-info {
  flex: 1;
}

.role-name {
  display: block;
  font-weight: 600;
  color: #1e293b;
}

.arrow {
  color: #cbd5e1;
  font-size: 12px;
}

.role-item.active .arrow {
  color: #3b82f6;
}

.loading-state {
  padding: 40px;
  text-align: center;
  color: #64748b;
}

@media (max-width: 1024px) {
  .roles-panel {
    width: 100%;
    height: 300px;
  }
}
</style>
