# 📍 Cómo Crear una Nueva Ruta

## Pasos para crear una ruta desde la interfaz

### 1️⃣ Acceder a la sección de Rutas
1. Abre la aplicación en `http://localhost:3000`
2. En el menú lateral izquierdo, haz click en **"Rutas"**
3. Verás el panel de control de rutas en el lado izquierdo del mapa

### 2️⃣ Iniciar el dibujo de la ruta
1. Haz click en el botón **"➕ Nueva Ruta"**
2. El sistema activará el modo de dibujo en el mapa
3. Verás un mensaje indicando que puedes hacer click en el mapa

### 3️⃣ Dibujar la ruta en el mapa
1. **Haz click en el mapa** para agregar el primer punto de la ruta
2. **Continúa haciendo click** para agregar más puntos (mínimo 2 puntos)
3. Cada click agregará un punto y se dibujará una línea conectándolos
4. Verás marcadores numerados (1, 2, 3...) en cada punto

### 4️⃣ Finalizar el dibujo
1. Cuando termines de dibujar la ruta, haz click en el botón **"Finalizar"**
2. Se abrirá automáticamente un modal con el formulario de la ruta

### 5️⃣ Completar el formulario
Completa los siguientes campos:

- **ID de Ruta**: Se genera automáticamente (RUTA_01, RUTA_02, etc.)
- **Nombre**: Nombre descriptivo de la ruta (ej: "Ruta Centro - Norte")
- **Color**: Selecciona un color para identificar la ruta en el mapa
- **Descripción**: Descripción detallada de la ruta (opcional)

### 6️⃣ Guardar la ruta
1. Haz click en el botón **"Guardar"**
2. El sistema guardará la ruta en PostgreSQL
3. La ruta aparecerá automáticamente en el listado del panel izquierdo
4. Verás la ruta dibujada en el mapa

## ✅ Verificación

### En la interfaz:
- La ruta debe aparecer en el listado del panel izquierdo
- La ruta debe ser visible en el mapa con el color seleccionado
- Los marcadores de inicio y fin deben ser visibles

### En la base de datos:
Puedes verificar que se guardó ejecutando esta consulta en PostgreSQL:

```sql
SELECT 
  id_route,
  name_route,
  descrip_route,
  color_route,
  ST_AsText(path_route) as path_text,
  ST_NumPoints(path_route) as num_points,
  status_route,
  created_at
FROM tab_routes 
ORDER BY created_at DESC 
LIMIT 5;
```

## 🔧 Solución de problemas

### La ruta no se guarda:
1. Verifica que el backend esté corriendo en `http://localhost:3002`
2. Revisa la consola del navegador (F12) para ver errores
3. Verifica la consola del terminal donde corre el backend

### No puedo dibujar en el mapa:
1. Asegúrate de hacer click en "Nueva Ruta" primero
2. Verifica que el mapa esté cargado completamente
3. Asegúrate de hacer al menos 2 clicks (mínimo 2 puntos)

### El modal no se abre:
1. Verifica que hayas hecho click en "Finalizar"
2. Asegúrate de tener al menos 2 puntos dibujados
3. Revisa la consola del navegador para errores

## 📊 Datos guardados

Cuando guardas una ruta, se almacenan los siguientes datos en PostgreSQL:

- **id_route**: ID numérico (1, 2, 3...)
- **name_route**: Nombre de la ruta
- **descrip_route**: Descripción
- **color_route**: Color en formato hexadecimal (#RRGGBB)
- **path_route**: Geometría LineString con las coordenadas GPS
- **status_route**: Estado (TRUE = activa, FALSE = eliminada)
- **user_create**: Usuario que creó la ruta (por defecto: 'admin')
- **created_at**: Fecha y hora de creación
- **updated_at**: Fecha y hora de última actualización

## 🎯 Funciones adicionales

### Ver/Ocultar ruta en el mapa:
- Click en el icono 👁️ junto a cada ruta en el listado

### Editar ruta:
- Click en el icono ✏️ junto a la ruta en el listado
- Modifica los campos necesarios
- Click en "Guardar"

### Mostrar todas las rutas:
- Click en el botón "🗺️ Mostrar Todas"
- Activa/desactiva la visibilidad de todas las rutas a la vez
