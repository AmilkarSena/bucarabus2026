<template>
  <!-- Checkbox personalizado para un permiso de rol (checked / unchecked) -->
  <div class="permission-checkbox">
    <label class="checkbox-container">
      <input
        type="checkbox"
        :value="permission.code_permission"
        :checked="checked"
        @change="$emit('change', permission.code_permission, $event.target.checked)"
      />
      <span class="checkmark"></span>
      <div class="perm-info">
        <span class="perm-name">{{ label }}</span>
        <span class="perm-desc">{{ permission.descrip_permission }}</span>
      </div>
    </label>
  </div>
</template>

<script setup>
defineProps({
  /** Objeto de permiso: { code_permission, name_permission, descrip_permission } */
  permission: { type: Object, required: true },
  /** Texto a mostrar como nombre (permite sobreescribir con "Acceso al Módulo") */
  label:      { type: String, required: true },
  /** Si el permiso está marcado */
  checked:    { type: Boolean, default: false }
})

defineEmits(['change'])
</script>

<style scoped>
.permission-checkbox { /* contenedor para el grid del padre */ }

.checkbox-container {
  display: flex;
  position: relative;
  padding-left: 32px;
  cursor: pointer;
  user-select: none;
  align-items: flex-start;
}

.checkbox-container input {
  position: absolute;
  opacity: 0;
  cursor: pointer;
  height: 0;
  width: 0;
}

.checkmark {
  position: absolute;
  top: 2px;
  left: 0;
  height: 20px;
  width: 20px;
  background-color: #f1f5f9;
  border: 1px solid #cbd5e1;
  border-radius: 4px;
  transition: all 0.2s;
}

.checkbox-container:hover input ~ .checkmark { background-color: #e2e8f0; }

.checkbox-container input:checked ~ .checkmark {
  background-color: #3b82f6;
  border-color: #3b82f6;
}

.checkmark:after {
  content: "";
  position: absolute;
  display: none;
}

.checkbox-container input:checked ~ .checkmark:after { display: block; }

.checkbox-container .checkmark:after {
  left: 6px;
  top: 2px;
  width: 5px;
  height: 10px;
  border: solid white;
  border-width: 0 2px 2px 0;
  transform: rotate(45deg);
}

.perm-info   { display: flex; flex-direction: column; }
.perm-name   { font-weight: 500; color: #1e293b; font-size: 14px; }
.perm-desc   { font-size: 12px; color: #64748b; margin-top: 2px; }
</style>
