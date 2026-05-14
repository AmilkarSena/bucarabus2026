<template>
  <div class="permissions-panel card">
    <!-- Estado vacío -->
    <div v-if="mode === 'role' ? !selectedRole : !selectedUser" class="empty-state">
      <span class="empty-icon">👈</span>
      <p v-if="mode === 'role'">Selecciona un rol a la izquierda para gestionar sus permisos</p>
      <p v-else>Selecciona un usuario a la izquierda para gestionar sus permisos individuales</p>
    </div>

    <div v-else class="permissions-content">
      <!-- Título -->
      <h2 class="panel-title" v-if="mode === 'role'">
        Permisos: {{ selectedRole.role_name }}
      </h2>
      <h2 class="panel-title" v-else>
        Overrides: {{ selectedUser.full_name }}
        <template v-if="selectedUser.roles && selectedUser.roles.length">
          <span v-for="role in selectedUser.roles" :key="role.id_role" class="user-role-tag">
            {{ role.role_name }}
          </span>
        </template>
        <span v-else-if="selectedUser.role_name" class="user-role-tag">
          {{ selectedUser.role_name }}
        </span>
      </h2>

      <!-- Subtítulo / leyenda -->
      <div v-if="mode === 'user'" class="user-mode-legend">
        <span class="legend-item">🔵 Heredado del rol</span>
        <span class="legend-item">🟢 Allow extra</span>
        <span class="legend-item">🔴 Deny (revocado)</span>
      </div>
      <p v-else class="help-text">
        Marca las casillas para otorgar acceso. Los cambios no se aplicarán hasta que presiones "Guardar Cambios".
      </p>

      <div v-if="loading" class="loading-state">Cargando permisos...</div>

      <!-- ─── Acordeón ─── -->
      <div v-else class="accordion-container">
        <div
          v-for="module in groupedPermissions"
          :key="module.id_permission"
          class="accordion-item"
          :class="{ open: expandedModules.includes(module.id_permission) }"
        >
          <!-- Cabecera -->
          <div class="accordion-header" @click.self="toggleModule(module.id_permission)">
            <div class="accordion-title" @click="toggleModule(module.id_permission)">
              <span class="toggle-icon">{{ expandedModules.includes(module.id_permission) ? '▼' : '▶' }}</span>
              <span class="module-name">{{ module.name_permission }}</span>
            </div>
            <!-- "Seleccionar Todo" solo en modo rol -->
            <div class="accordion-actions" v-if="mode === 'role'">
              <label class="select-all-label" @click.stop>
                <input
                  type="checkbox"
                  :checked="isModuleFullySelected(module)"
                  :indeterminate="isModulePartiallySelected(module)"
                  @change="toggleSelectAll(module, $event.target.checked)"
                />
                Seleccionar Todo
              </label>
            </div>
          </div>

          <!-- Cuerpo: delega el render de cada ítem a los sub-componentes -->
          <div class="accordion-body" v-show="expandedModules.includes(module.id_permission)">
            <div class="permissions-grid">
              <template v-if="module.children.length > 0">
                <!-- Modo Rol -->
                <template v-if="mode === 'role'">
                  <RolePermissionItem
                    v-for="child in module.children"
                    :key="child.id_permission"
                    :permission="child"
                    :label="child.name_permission"
                    :checked="checkedPermissions.includes(child.code_permission)"
                    @change="onCheckboxChange"
                  />
                </template>
                <!-- Modo Usuario -->
                <template v-else>
                  <UserPermissionItem
                    v-for="child in module.children"
                    :key="child.id_permission"
                    :permission="child"
                    :label="child.name_permission"
                    :rolePermissions="rolePermissions"
                    :userOverrides="userOverrides"
                    @click="onUserPermClick"
                  />
                </template>
              </template>

              <!-- Módulo sin hijos: el propio módulo es el ítem -->
              <template v-else>
                <RolePermissionItem
                  v-if="mode === 'role'"
                  :permission="module"
                  label="Acceso al Módulo"
                  :checked="checkedPermissions.includes(module.code_permission)"
                  @change="onCheckboxChange"
                />
                <UserPermissionItem
                  v-else
                  :permission="module"
                  label="Acceso al Módulo"
                  :rolePermissions="rolePermissions"
                  :userOverrides="userOverrides"
                  @click="onUserPermClick"
                />
              </template>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, watch, computed } from 'vue'
import RolePermissionItem from './RolePermissionItem.vue'
import UserPermissionItem from './UserPermissionItem.vue'

const props = defineProps({
  groupedPermissions: { type: Array,   required: true },
  // Modo Rol
  selectedRole:        { type: Object,  default: null },
  checkedPermissions:  { type: Array,   default: () => [] },
  // Modo Usuario
  mode:                { type: String,  default: 'role' },  // 'role' | 'user'
  selectedUser:        { type: Object,  default: null },
  rolePermissions:     { type: Array,   default: () => [] },
  userOverrides:       { type: Array,   default: () => [] },
  // Común
  loading:             { type: Boolean, default: false }
})

const emit = defineEmits(['update:checkedPermissions', 'update:userOverrides'])

// ─── Acordeón ───────────────────────────────────────────────────────────────
const expandedModules = ref([])

watch(() => props.groupedPermissions, (newVal) => {
  if (newVal && newVal.length > 0 && expandedModules.value.length === 0) {
    expandedModules.value = [newVal[0].id_permission]
  }
}, { immediate: true })

const toggleModule = (moduleId) => {
  const index = expandedModules.value.indexOf(moduleId)
  if (index > -1) expandedModules.value.splice(index, 1)
  else            expandedModules.value.push(moduleId)
}

// ─── Modo Rol ────────────────────────────────────────────────────────────────
const getModulePermissionCodes = (module) =>
  module.children.length === 0
    ? [module.code_permission]
    : module.children.map(c => c.code_permission)

const isModuleFullySelected = (module) => {
  const codes = getModulePermissionCodes(module)
  return codes.length > 0 && codes.every(code => props.checkedPermissions.includes(code))
}

const isModulePartiallySelected = (module) => {
  const codes = getModulePermissionCodes(module)
  const count = codes.filter(code => props.checkedPermissions.includes(code)).length
  return count > 0 && count < codes.length
}

const toggleSelectAll = (module, isChecked) => {
  const codes = getModulePermissionCodes(module)
  let newChecked = [...props.checkedPermissions]
  if (isChecked) {
    codes.forEach(code => { if (!newChecked.includes(code)) newChecked.push(code) })
  } else {
    newChecked = newChecked.filter(code => !codes.includes(code))
  }
  emit('update:checkedPermissions', newChecked)
}

const onCheckboxChange = (code, isChecked) => {
  let newChecked = [...props.checkedPermissions]
  if (isChecked) { if (!newChecked.includes(code)) newChecked.push(code) }
  else           { newChecked = newChecked.filter(c => c !== code) }
  emit('update:checkedPermissions', newChecked)
}

// ─── Modo Usuario ────────────────────────────────────────────────────────────
const onUserPermClick = (code) => {
  const override  = props.userOverrides.find(o => o.code === code)
  const inRole    = props.rolePermissions.includes(code)
  const isGranted = override?.is_granted

  let newOverrides = props.userOverrides.filter(o => o.code !== code)

  // inherited → deny | none → allow | deny/allow → quitar override
  if (!override && inRole)        newOverrides.push({ code, is_granted: false })
  else if (!override && !inRole)  newOverrides.push({ code, is_granted: true })
  // si ya había override → se eliminó arriba (vuelve a estado base)

  emit('update:userOverrides', newOverrides)
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
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 6px;
}

.permissions-panel {
  flex: 1;
  background: #f8fafc;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  min-height: 0;
}

.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 100%;
  color: #64748b;
  text-align: center;
  padding: 40px;
}

.empty-icon { font-size: 48px; margin-bottom: 16px; opacity: 0.5; }

.permissions-content {
  display: flex;
  flex-direction: column;
  flex: 1;
  min-height: 0;
}

.help-text {
  padding: 12px 20px;
  margin: 0;
  color: #64748b;
  font-size: 13px;
  background: white;
  border-bottom: 1px solid #e2e8f0;
}

.user-mode-legend {
  display: flex;
  gap: 16px;
  padding: 10px 20px;
  background: white;
  border-bottom: 1px solid #e2e8f0;
  font-size: 12px;
  font-weight: 500;
  flex-wrap: wrap;
}

.user-role-tag {
  font-size: 12px;
  font-weight: 400;
  background: #eef2ff;
  color: #6366f1;
  border-radius: 4px;
  padding: 2px 8px;
}

.accordion-container {
  padding: 16px 20px 24px;
  overflow-y: auto;
  height: calc(100vh - 380px);
  display: flex;
  flex-direction: column;
  gap: 12px;
  scrollbar-width: thin;
  scrollbar-color: #cbd5e1 #f1f5f9;
}

.accordion-container::-webkit-scrollbar       { width: 6px; }
.accordion-container::-webkit-scrollbar-track { background: #f1f5f9; border-radius: 10px; }
.accordion-container::-webkit-scrollbar-thumb { background: #cbd5e1; border-radius: 10px; }
.accordion-container::-webkit-scrollbar-thumb:hover { background: #94a3b8; }

.accordion-item {
  background: white;
  border-radius: 8px;
  border: 1px solid #e2e8f0;
  overflow: hidden;
  box-shadow: 0 1px 2px rgba(0,0,0,0.05);
  flex-shrink: 0;
}

.accordion-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 16px 20px;
  background: #f8fafc;
  cursor: pointer;
  user-select: none;
  transition: background 0.2s;
}

.accordion-header:hover { background: #f1f5f9; }

.accordion-item.open .accordion-header {
  border-bottom: 1px solid #e2e8f0;
  background: #f1f5f9;
}

.accordion-title {
  display: flex;
  align-items: center;
  font-weight: 600;
  color: #1e293b;
  flex: 1;
}

.toggle-icon { width: 20px; font-size: 12px; color: #64748b; }

.select-all-label {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 13px;
  color: #475569;
  cursor: pointer;
  padding: 4px 8px;
  border-radius: 4px;
}

.select-all-label:hover { background: #e2e8f0; }

.accordion-body { padding: 20px; background: white; }

.permissions-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 16px;
}

.loading-state { padding: 40px; text-align: center; color: #64748b; }

@media (max-width: 1024px) {
  .permissions-panel { height: 500px; }
}
</style>
