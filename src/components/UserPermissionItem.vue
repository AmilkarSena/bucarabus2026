<template>
  <!--
    Item de permiso en modo usuario.
    Muestra 4 estados visuales y cicla entre ellos al hacer click.
    Estados: inherited (azul) → deny (rojo) → inherited
             none (vacío)    → allow (verde) → none
  -->
  <div
    class="user-perm-item"
    :class="state"
    @click="$emit('click', permission.code_permission)"
  >
    <span class="state-icon">{{ icon }}</span>
    <div class="perm-info">
      <span class="perm-name">{{ label }}</span>
      <span class="perm-desc">{{ permission.descrip_permission }}</span>
    </div>
    <span class="state-badge">{{ badge }}</span>
  </div>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  /** Objeto de permiso: { code_permission, name_permission, descrip_permission } */
  permission:      { type: Object, required: true },
  /** Texto a mostrar como nombre (permite sobreescribir con "Acceso al Módulo") */
  label:           { type: String, required: true },
  /** Códigos de permisos heredados del rol del usuario */
  rolePermissions: { type: Array, required: true },
  /** Array de overrides individuales: [{code, is_granted}] */
  userOverrides:   { type: Array, required: true }
})

defineEmits(['click'])

/** Calcula el estado actual del permiso */
const state = computed(() => {
  const code     = props.permission.code_permission
  const override = props.userOverrides.find(o => o.code === code)
  if (override) return override.is_granted ? 'state-allow' : 'state-deny'
  return props.rolePermissions.includes(code) ? 'state-inherited' : 'state-none'
})

const icon = computed(() => {
  if (state.value === 'state-inherited') return '🔵'
  if (state.value === 'state-allow')     return '🟢'
  if (state.value === 'state-deny')      return '🔴'
  return '⬜'
})

const badge = computed(() => {
  if (state.value === 'state-inherited') return 'Rol'
  if (state.value === 'state-allow')     return '+Allow'
  if (state.value === 'state-deny')      return '−Deny'
  return ''
})
</script>

<style scoped>
.user-perm-item {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 12px;
  border-radius: 8px;
  cursor: pointer;
  border: 2px solid #e2e8f0;
  transition: all 0.15s;
  user-select: none;
}
.user-perm-item:hover { filter: brightness(0.97); }

.user-perm-item.state-inherited { border-color: #93c5fd; background: #eff6ff; }
.user-perm-item.state-allow     { border-color: #86efac; background: #f0fdf4; }
.user-perm-item.state-deny      { border-color: #fca5a5; background: #fff1f2; opacity: 0.85; }
.user-perm-item.state-none      { background: #f8fafc; }

.state-icon  { font-size: 16px; flex-shrink: 0; }

.state-badge {
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 0.5px;
  flex-shrink: 0;
  padding: 2px 6px;
  border-radius: 4px;
  background: rgba(0,0,0,0.06);
  color: #475569;
}

.perm-info   { display: flex; flex-direction: column; flex: 1; }
.perm-name   { font-weight: 500; color: #1e293b; font-size: 14px; }
.perm-desc   { font-size: 12px; color: #64748b; margin-top: 2px; }
</style>
