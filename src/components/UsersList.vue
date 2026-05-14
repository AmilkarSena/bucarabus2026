<template>
  <div class="users-panel card">
    <h2 class="panel-title">Usuarios</h2>

    <div v-if="loading" class="loading-state">Cargando usuarios...</div>

    <ul v-else class="user-list">
      <li
        v-for="user in users"
        :key="user.id_user"
        class="user-item"
        :class="{ active: selectedUserId === user.id_user }"
        @click="$emit('select-user', user)"
      >
        <!-- Avatar con inicial del nombre -->
        <div class="user-avatar" :style="{ background: avatarColor(user.full_name) }">
          {{ initial(user.full_name) }}
        </div>

        <div class="user-info">
          <span class="user-name">{{ user.full_name }}</span>
          <!-- Muestra todos los roles como badges independientes -->
          <div class="user-roles">
            <template v-if="user.roles && user.roles.length">
              <span
                v-for="role in user.roles"
                :key="role.id_role"
                class="user-role-badge"
              >{{ role.role_name }}</span>
            </template>
            <span v-else-if="user.role_name" class="user-role-badge">{{ user.role_name }}</span>
            <span v-else class="user-role-badge no-role">Sin rol</span>
          </div>
        </div>

        <span class="arrow">▶</span>
      </li>
    </ul>
  </div>
</template>

<script setup>
defineProps({
  users: {
    type: Array,
    required: true
  },
  loading: {
    type: Boolean,
    default: false
  },
  selectedUserId: {
    type: Number,
    default: null
  }
})

defineEmits(['select-user'])

/** Genera la inicial del nombre para el avatar */
function initial(fullName) {
  return fullName?.trim()?.[0]?.toUpperCase() || '?'
}

/**
 * Color de fondo del avatar basado en el nombre (determinístico).
 * Usa el mismo código de carácter para asegurar que el mismo usuario
 * siempre tenga el mismo color, sin necesidad de guardar nada.
 */
function avatarColor(fullName) {
  const colors = [
    '#3b82f6', '#8b5cf6', '#ec4899', '#f59e0b',
    '#10b981', '#06b6d4', '#f97316', '#6366f1'
  ]
  const index = (fullName?.charCodeAt(0) || 0) % colors.length
  return colors[index]
}
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

.users-panel {
  width: 320px;
  flex-shrink: 0;
  height: 100%;
}

.user-list {
  list-style: none;
  padding: 0;
  margin: 0;
  overflow-y: auto;
  flex: 1;
}

.user-item {
  display: flex;
  align-items: center;
  padding: 12px 20px;
  cursor: pointer;
  border-bottom: 1px solid #f1f5f9;
  transition: all 0.2s;
}

.user-item:hover {
  background: #f8fafc;
}

.user-item.active {
  background: #eff6ff;
  border-left: 4px solid #3b82f6;
}

/* Avatar circular con inicial */
.user-avatar {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 16px;
  font-weight: 700;
  color: white;
  flex-shrink: 0;
  margin-right: 14px;
}

.user-info {
  flex: 1;
  min-width: 0;
}

.user-name {
  display: block;
  font-weight: 600;
  color: #1e293b;
  font-size: 14px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

/* Contenedor de badges — flujo horizontal con wrap */
.user-roles {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
  margin-top: 3px;
}

.user-role-badge {
  display: inline-block;
  font-size: 11px;
  font-weight: 500;
  color: #6366f1;
  background: #eef2ff;
  border-radius: 4px;
  padding: 1px 6px;
}

.user-role-badge.no-role {
  color: #94a3b8;
  background: #f1f5f9;
}

.user-item.active .user-role-badge {
  background: #dbeafe;
  color: #1d4ed8;
}

.arrow {
  color: #cbd5e1;
  font-size: 12px;
  flex-shrink: 0;
}

.user-item.active .arrow {
  color: #3b82f6;
}

.loading-state {
  padding: 40px;
  text-align: center;
  color: #64748b;
}

@media (max-width: 1024px) {
  .users-panel {
    width: 100%;
    height: 300px;
  }
}
</style>
