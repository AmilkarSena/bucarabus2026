<template>
  <div class="destination-search">
    <div class="search-input-wrapper">
      <span class="search-icon">📍</span>
      <input
        :value="modelValue"
        @input="onInput"
        @focus="$emit('show-results')"
        type="text"
        placeholder="¿A dónde vas?"
        class="search-input"
      />
      <button
        v-if="hasDestination"
        @click="$emit('clear')"
        class="btn-clear-dest"
        title="Limpiar destino"
      >✕</button>
    </div>

    <div v-if="showResults && results.length > 0" class="search-results-dropdown">
      <div
        v-for="(result, idx) in results.slice(0, 5)"
        :key="idx"
        class="search-result-item"
        @click="$emit('select', result)"
      >
        <span class="search-result-icon">📍</span>
        <div class="search-result-text">
          <div class="search-result-name">{{ result.name }}</div>
          <div v-if="result.address" class="search-result-address">{{ result.address }}</div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
defineProps({
  modelValue: { type: String, default: '' },
  results: { type: Array, default: () => [] },
  showResults: { type: Boolean, default: false },
  hasDestination: { type: Boolean, default: false }
})

const emit = defineEmits(['update:modelValue', 'search', 'show-results', 'select', 'clear'])

const onInput = (event) => {
  emit('update:modelValue', event.target.value)
  emit('search')
}
</script>

<style scoped>
.destination-search {
  position: absolute;
  top: 85px;
  left: 12px;
  right: 70px;
  z-index: 800;
}

.search-input-wrapper {
  display: flex;
  align-items: center;
  background: white;
  border-radius: 25px;
  box-shadow: 0 4px 12px rgba(0,0,0,0.15);
  overflow: hidden;
}

.search-icon {
  padding: 8px;
  font-size: 1.2rem;
}

.search-input {
  flex: 1;
  border: none;
  outline: none;
  padding: 8px 4px;
  font-size: 16px;
  background: transparent;
}

.search-input::placeholder { color: #999; }

.btn-clear-dest {
  background: none;
  border: none;
  color: #999;
  font-size: 1.2rem;
  cursor: pointer;
  padding: 8px 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  min-width: 32px;
  height: 32px;
  flex-shrink: 0;
}

.btn-clear-dest:hover { color: #333; }

.search-results-dropdown {
  position: absolute;
  top: calc(100% + 4px);
  left: 0;
  right: 0;
  z-index: 850;
  background: white;
  border-radius: 12px;
  box-shadow: 0 4px 16px rgba(0,0,0,0.18);
  overflow: hidden;
  max-height: 250px;
  overflow-y: auto;
}

.search-result-item {
  padding: 12px;
  border-bottom: 1px solid #f0f0f0;
  cursor: pointer;
  transition: background 0.2s;
  display: flex;
  align-items: center;
  gap: 12px;
}

.search-result-item:last-child { border-bottom: none; }
.search-result-item:hover { background: #f8f9fa; }

.search-result-icon { font-size: 1.2rem; }
.search-result-text { flex: 1; }
.search-result-name { font-weight: 500; color: #333; }
.search-result-address { font-size: 0.8rem; color: #999; margin-top: 2px; }
</style>
