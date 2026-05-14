<template>
  <div v-if="modelValue" class="legal-modal-overlay" @click.self="close">
    <div class="legal-modal">
      <div class="legal-modal-header">
        <h3>{{ currentContent.title }}</h3>
        <button class="close-legal-btn" @click="close">×</button>
      </div>
      
      <div class="legal-modal-content">
        <div v-html="currentContent.body"></div>
      </div>
      
      <div class="legal-modal-footer">
        <button class="btn-close-modal" @click="close">Entendido</button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  modelValue: Boolean,
  section: {
    type: String,
    default: 'terms'
  }
})

const emit = defineEmits(['update:modelValue'])

const close = () => {
  emit('update:modelValue', false)
}

const legalData = {
  terms: {
    title: 'Términos y Condiciones de Uso',
    body: `
      <section>
        <p>Bienvenido a <strong>BucaraBus</strong>. Al acceder a nuestra plataforma, aceptas cumplir con los siguientes términos:</p>
        <ul>
          <li><strong>Objeto:</strong> BucaraBus es una herramienta tecnológica para la gestión, monitoreo y optimización del transporte urbano.</li>
          <li><strong>Uso de la Plataforma:</strong> El acceso es personal y el usuario es responsable de la confidencialidad de sus credenciales.</li>
          <li><strong>Limitación de Responsabilidad:</strong> La precisión de la ubicación GPS depende de factores externos como la cobertura de red y satélites.</li>
          <li><strong>Normativa:</strong> Estos términos se rigen por las leyes de la República de Colombia.</li>
        </ul>
      </section>
    `
  },
  privacy: {
    title: 'Política de Privacidad',
    body: `
      <section>
        <p>En cumplimiento de la <strong>Ley 1581 de 2012 (Habeas Data)</strong>, informamos:</p>
        <ul>
          <li><strong>Datos Recolectados:</strong> Recopilamos datos de geolocalización en tiempo real para la visualización de rutas y seguridad del servicio.</li>
          <li><strong>Finalidad:</strong> Los datos se utilizan exclusivamente para la gestión operativa del transporte.</li>
          <li><strong>Seguridad:</strong> Implementamos medidas técnicas para proteger tu información contra accesos no autorizados.</li>
          <li><strong>Tus Derechos:</strong> Puedes solicitar la actualización o eliminación de tus datos enviando un correo a soporte@bucarabus.com.</li>
        </ul>
      </section>
    `
  },
  cookies: {
    title: 'Política de Cookies',
    body: `
      <section>
        <p>Utilizamos cookies para mejorar tu experiencia en BucaraBus:</p>
        <ul>
          <li><strong>Cookies Técnicas:</strong> Esenciales para mantener tu sesión activa y recordar tus preferencias.</li>
          <li><strong>Cookies de Rendimiento:</strong> Nos ayudan a entender cómo se usa la app para optimizar su velocidad.</li>
          <li><strong>Gestión:</strong> Puedes configurar tu navegador para bloquear cookies, aunque esto podría afectar la funcionalidad.</li>
        </ul>
      </section>
    `
  }
}

const currentContent = computed(() => {
  return legalData[props.section] || legalData.terms
})
</script>

<style scoped>
.legal-modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background: rgba(15, 23, 42, 0.7);
  backdrop-filter: blur(5px);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 10000;
  padding: 20px;
}

.legal-modal {
  background: white;
  width: 100%;
  max-width: 550px;
  max-height: 80vh;
  border-radius: 20px;
  box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
  display: flex;
  flex-direction: column;
  animation: modalSlideUp 0.3s ease-out;
}

.legal-modal-header {
  padding: 20px 25px;
  border-bottom: 1px solid #f1f5f9;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.legal-modal-header h3 {
  margin: 0;
  font-size: 1.2rem;
  color: #1e293b;
  font-weight: 700;
}

.close-legal-btn {
  background: none;
  border: none;
  font-size: 2rem;
  color: #94a3b8;
  cursor: pointer;
  line-height: 1;
}

.legal-modal-content {
  padding: 25px;
  overflow-y: auto;
  color: #475569;
  line-height: 1.6;
}

:deep(section p) {
  margin-bottom: 1rem;
}

:deep(ul) {
  padding-left: 1.25rem;
}

:deep(li) {
  margin-bottom: 0.75rem;
}

.legal-modal-footer {
  padding: 15px 25px;
  border-top: 1px solid #f1f5f9;
  display: flex;
  justify-content: flex-end;
}

.btn-close-modal {
  padding: 8px 20px;
  background: #6366f1;
  color: white;
  border: none;
  border-radius: 10px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-close-modal:hover {
  background: #4f46e5;
  transform: translateY(-1px);
}

@keyframes modalSlideUp {
  from { opacity: 0; transform: translateY(30px); }
  to { opacity: 1; transform: translateY(0); }
}
</style>
