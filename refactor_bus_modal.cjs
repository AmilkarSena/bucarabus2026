const fs = require('fs');
let code = fs.readFileSync('src/components/modals/BusModal.vue', 'utf8');

// 1. Modularizar Header
code = code.replace(
  /<!-- Header con Foto y Switches -->[\s\S]*?<!-- Sub-componentes visuales/,
  `<!-- Header con Foto y Switches -->
      <BusFormHeader />

      <!-- Sub-componentes visuales`
);

// 2. Importar Header
code = code.replace(
  /import BusFormTechInfo from '\.\/bus\/BusFormTechInfo\.vue'/,
  `import BusFormTechInfo from './bus/BusFormTechInfo.vue'
import BusFormHeader from './bus/BusFormHeader.vue'`
);

// 3. Eliminar ref redundante
code = code.replace(/const fileInput = ref\(null\)\n/, '');

// 4. Simplificar Provide y Métodos
// Primero eliminamos handleStatusChange manual
code = code.replace(/const handleStatusChange = \(\) => \{[\s\S]*?originalHandleStatusChange\(formData\.value, props\.data\)\s+\}/, '');

// Actualizamos provide
code = code.replace(
  /provide\('busFormContext', \{[\s\S]*?\}\)/,
  `provide('busFormContext', {
  formData,
  errors,
  isEditMode,
  companies,
  busOwners,
  brands,
  currentYear,
  validatePlateField,
  validateAmbCodeField,
  validateCodeInternalField,
  validateIdCompanyField,
  validateModelYearField,
  validateCapacityField,
  validateColorBusField,
  validateIdOwnerField,
  validateModelNameField,
  validateColorAppField,
  handleStatusChange: () => originalHandleStatusChange(formData.value, props.data)
})`
);

// 5. Eliminar métodos de foto movidos
code = code.replace(/const handleImageError = \(event\) => \{[\s\S]*?handleFileUpload = async \(event\) => \{[\s\S]*?\}\n\}/, '');

// 6. Limpiar estilos
code = code.replace(/<style scoped>[\s\S]*?<\/style>/, `<style scoped>
/* 
  Los estilos compartidos están en src/assets/modal-forms.css
*/
</style>`);

fs.writeFileSync('src/components/modals/BusModal.vue', code, 'utf8');
console.log('BusModal refactored successfully!');
