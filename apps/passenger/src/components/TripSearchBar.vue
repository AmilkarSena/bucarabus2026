<template>
  <div class="trip-search-bar">

    <!-- ── ORIGEN ── -->
    <Transition name="slide-origin">
      <div v-if="hasDestination" class="origin-block">
        <div class="search-field">
          <span class="field-dot origin-dot"></span>
          <input
            ref="originRef"
            :value="originQuery"
            @input="onOriginInput"
            @focus="activeField = 'origin'"
            @blur="closeWithDelay"
            type="text"
            :placeholder="originPlaceholder"
            class="field-input"
          />
          <button
            class="btn-swap"
            @click="$emit('swap')"
            title="Intercambiar origen y destino"
          >↕</button>
          <button
            v-if="hasOrigin || originQuery"
            class="btn-clear"
            @mousedown.prevent="$emit('clear-origin')"
            title="Usar mi ubicación GPS"
          >✕</button>
        </div>
      </div>
    </Transition>

    <!-- ── DESTINO ──────────────────────────────── -->
    <div class="search-field">
      <span class="field-dot dest-dot"></span>
      <input
        ref="destRef"
        :value="destinationQuery"
        @input="onDestInput"
        @focus="activeField = 'destination'"
        @blur="closeWithDelay"
        type="text"
        placeholder="¿A dónde vas?"
        class="field-input"
      />
      <button
        v-if="hasDestination || destinationQuery"
        class="btn-clear"
        @mousedown.prevent="$emit('clear-destination')"
        title="Limpiar destino"
      >✕</button>
    </div>

    <!-- ── DROPDOWN RESULTADOS ORIGEN ──────────── -->
    <div v-if="activeField === 'origin' && originResults.length > 0" class="results-dropdown">
      <div
        v-for="(r, i) in originResults.slice(0, 5)"
        :key="'o-' + i"
        class="result-item"
        @mousedown.prevent="pickOrigin(r)"
      >
        <span class="result-dot origin-rdot"></span>
        <div class="result-text">
          <div class="result-name">{{ r.name }}</div>
          <div v-if="r.address" class="result-address">{{ r.address }}</div>
        </div>
      </div>
    </div>

    <!-- ── DROPDOWN RESULTADOS DESTINO ─────────── -->
    <div v-if="activeField === 'destination' && destinationResults.length > 0" class="results-dropdown">
      <div
        v-for="(r, i) in destinationResults.slice(0, 5)"
        :key="'d-' + i"
        class="result-item"
        @mousedown.prevent="pickDestination(r)"
      >
        <span class="result-dot dest-rdot"></span>
        <div class="result-text">
          <div class="result-name">{{ r.name }}</div>
          <div v-if="r.address" class="result-address">{{ r.address }}</div>
        </div>
      </div>
    </div>

  </div>
</template>

<script setup>
import { ref, computed } from 'vue'

const props = defineProps({
  originQuery:        { type: String,  default: '' },
  destinationQuery:   { type: String,  default: '' },
  originResults:      { type: Array,   default: () => [] },
  destinationResults: { type: Array,   default: () => [] },
  hasOrigin:          { type: Boolean, default: false },
  hasDestination:     { type: Boolean, default: false },
  userLocationName:   { type: String,  default: '' }   // dirección textual GPS del padre
})

// Placeholder dinámico del campo de origen
const originPlaceholder = computed(() => {
  if (props.hasOrigin) return ''
  if (props.userLocationName) return `📍 Mi ubicación : ${props.userLocationName}`
  return '📍 Mi ubicación'
})

const emit = defineEmits([
  'search-origin', 'search-destination',
  'select-origin', 'select-destination',
  'clear-origin',  'clear-destination',
  'swap'
])

const activeField = ref(null)
let closeTimer = null

const closeWithDelay = () => {
  closeTimer = setTimeout(() => { activeField.value = null }, 150)
}

const onOriginInput = (e) => {
  emit('search-origin', e.target.value)
}

const onDestInput = (e) => {
  emit('search-destination', e.target.value)
}

const pickOrigin = (r) => {
  clearTimeout(closeTimer)
  activeField.value = null
  emit('select-origin', r)
}

const pickDestination = (r) => {
  clearTimeout(closeTimer)
  activeField.value = null
  emit('select-destination', r)
}
</script>

<style scoped>
.trip-search-bar {
  background: white;
  border-radius: 16px;
  box-shadow: 0 4px 16px rgba(0,0,0,0.14);
  overflow: visible;
  position: relative;
}

/* ── Fila de campo ── */
.search-field {
  display: flex;
  align-items: center;
  padding: 0 12px;
  height: 48px;
  gap: 10px;
}

/* ── Puntos indicadores ── */
.field-dot {
  width: 11px;
  height: 11px;
  border-radius: 50%;
  flex-shrink: 0;
}
.origin-dot {
  background: white;
  border: 2.5px solid #94a3b8;
}
.dest-dot {
  background: #f97316;
  border: 2.5px solid #f97316;
}

/* ── Input ── */
.field-input {
  flex: 1;
  border: none;
  outline: none;
  font-size: 15px;
  color: #1e293b;
  background: transparent;
  min-width: 0;
}
.field-input::placeholder { color: #94a3b8; }

/* ── Botón limpiar ── */
.btn-clear {
  background: none;
  border: none;
  color: #94a3b8;
  font-size: 14px;
  cursor: pointer;
  padding: 4px 6px;
  line-height: 1;
  flex-shrink: 0;
  border-radius: 50%;
  transition: color 0.2s, background 0.2s;
}
.btn-clear:hover { color: #475569; background: #f1f5f9; }

/* ── Botón swap ── */
.btn-swap {
  flex-shrink: 0;
  width: 28px;
  height: 28px;
  border-radius: 50%;
  background: #1e293b;
  color: white;
  border: none;
  font-size: 13px;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 2px 6px rgba(0,0,0,0.2);
  transition: background 0.2s, transform 0.3s ease;
}
.btn-swap:hover {
  background: #334155;
  transform: rotate(180deg);
}

/* ── Dropdown resultados ── */
.results-dropdown {
  position: absolute;
  top: calc(100% + 6px);
  left: 0;
  right: 0;
  background: white;
  border-radius: 14px;
  box-shadow: 0 6px 20px rgba(0,0,0,0.16);
  overflow: hidden;
  z-index: 900;
}

.result-item {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 16px;
  border-bottom: 1px solid #f1f5f9;
  cursor: pointer;
  transition: background 0.15s;
}
.result-item:last-child { border-bottom: none; }
.result-item:hover { background: #f8fafc; }

.result-dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  flex-shrink: 0;
}
.origin-rdot { background: #94a3b8; border: 2px solid #94a3b8; }
.dest-rdot   { background: #f97316; border: 2px solid #f97316; }

.result-text  { flex: 1; min-width: 0; }
.result-name  { font-size: 14px; font-weight: 500; color: #1e293b; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.result-address { font-size: 12px; color: #94a3b8; margin-top: 2px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }

/* ── Bloque origen (solo el campo, sin separador) ── */
.origin-block {
  overflow: hidden;
}

/* ── Animación slide-down ── */
.slide-origin-enter-active {
  transition: max-height 0.3s ease, opacity 0.25s ease;
}
.slide-origin-leave-active {
  transition: max-height 0.25s ease, opacity 0.2s ease;
}
.slide-origin-enter-from,
.slide-origin-leave-to {
  max-height: 0;
  opacity: 0;
}
.slide-origin-enter-to,
.slide-origin-leave-from {
  max-height: 92px; /* 48px campo + 44px separador */
  opacity: 1;
}
</style>
