<template>
  <div class="modal-header-section">
    <div class="photo-upload-section">
      <div class="photo-circle" @click="triggerFileInput" title="Click para cambiar foto">
        <img v-if="formData.photo_driver" :src="formData.photo_driver" alt="Foto" @error="handleImageError" />
        <div v-else class="photo-placeholder">
          <span>📷</span>
        </div>
      </div>
      <input
        ref="fileInput"
        type="file"
        accept="image/*"
        style="display: none"
        @change="handleFileUpload"
      />
    </div>
    
    <div class="status-switches">
      <label class="switch-item">
        <span class="switch-text">Activo</span>
        <div class="switch">
          <input type="checkbox" v-model="formData.is_active" @change="onStatusChange" />
          <span class="slider"></span>
        </div>
      </label>
    </div>
  </div>
</template>

<script setup>
import { ref, inject } from 'vue'

const {
  formData,
  handleStatusChange
} = inject('driverFormContext')

const fileInput = ref(null)

const triggerFileInput = () => {
  fileInput.value?.click()
}

const handleImageError = (event) => {
  event.target.src = 'https://via.placeholder.com/150?text=Sin+Foto'
}

const onStatusChange = () => {
  handleStatusChange()
}

const handleFileUpload = async (event) => {
  const file = event.target.files?.[0]
  if (!file) return

  if (!file.type.startsWith('image/')) {
    alert('Solo se permiten archivos de imagen')
    return
  }

  if (file.size > 5 * 1024 * 1024) {
    alert('La imagen es muy grande. Máximo 5MB')
    return
  }

  try {
    const temporaryUrl = URL.createObjectURL(file)
    formData.value.photo_driver = temporaryUrl
    console.warn('⚠️ Imagen cargada temporalmente. Debes implementar la subida al servidor.')
    console.log('📁 Archivo seleccionado:', file.name, 'Tamaño:', (file.size / 1024).toFixed(2), 'KB')
  } catch (error) {
    console.error('Error al procesar imagen:', error)
    alert('Error al procesar la imagen')
  }
}
</script>
