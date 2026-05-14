const fs = require('fs');
let code = fs.readFileSync('src/components/modals/DriverModal.vue', 'utf8');

// 1. Reemplazar HTML Header
code = code.replace(
  /<!-- Header con Foto y Switch -->[\s\S]*?<!-- Información Personal -->/,
  `<!-- Header con Foto y Switch -->
        <DriverFormHeader />

        <!-- Información Personal -->`
);

// 2. Reemplazar HTML Información Adicional
code = code.replace(
  /<!-- Información Adicional -->[\s\S]*?<!-- Mensaje de Error Global -->/,
  `<!-- Información Adicional -->
        <DriverFormAdditionalInfo />

        <!-- Mensaje de Error Global -->`
);

// 3. Importar los subcomponentes
code = code.replace(
  /import DriverFormLicenseInfo from '\.\/driver\/DriverFormLicenseInfo\.vue'/,
  `import DriverFormLicenseInfo from './driver/DriverFormLicenseInfo.vue'
import DriverFormHeader from './driver/DriverFormHeader.vue'
import DriverFormAdditionalInfo from './driver/DriverFormAdditionalInfo.vue'`
);

// 4. Eliminar ref
code = code.replace(/const fileInput = ref\(null\)\n*/, '');

// 5. Provide handleStatusChange
code = code.replace(
  /provide\('driverFormContext', \{[\s\S]*?validateBirthdateField\n\}\)/,
  `provide('driverFormContext', {
  formData,
  errors,
  isEditMode,
  today,
  minLicenseDate,
  epsList,
  arlList,
  calculateAge,
  getLicenseValidityMessage,
  calculateMaxLicenseExpDate,
  validateNameField,
  validateCedulaField,
  validatePhoneField,
  validateEmailField,
  validateLicenseExpField,
  validateBirthdateField,
  handleStatusChange: () => originalHandleStatusChange(formData.value)
})`
);

// 6. Eliminar métodos obsoletos
const methodsToDelete = [
  /const handleStatusChange = \(\) => \{[\s\S]*?originalHandleStatusChange\(formData\.value\)[\s\S]*?\}\n/,
  /const handleImageError = \(event\) => \{[\s\S]*?\}\n/,
  /const triggerFileInput = \(\) => \{[\s\S]*?\}\n/,
  /const handleFileUpload = async \(event\) => \{[\s\S]*?catch \(error\) \{[\s\S]*?\}[\s\S]*?\}\n/,
  /const formatDateTime = \(dateTime\) => \{[\s\S]*?\}\n/
];

methodsToDelete.forEach(regex => {
  code = code.replace(regex, '');
});

// Limpiar doble linea vacía
code = code.replace(/\n\s*\n\s*\n/g, '\n\n');

fs.writeFileSync('src/components/modals/DriverModal.vue', code, 'utf8');
console.log('DriverModal refactored successfully!');
