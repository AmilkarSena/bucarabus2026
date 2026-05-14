# Documento de Especificaciones Técnicas y Funcionales - BucaraBus

## 1. Introducción

BucaraBus es una plataforma integral para la gestión, monitoreo y optimización del transporte público urbano en la ciudad de Bucaramanga. El sistema conecta a administradores, conductores y pasajeros en tiempo real para mejorar la eficiencia operativa y la experiencia del usuario.

## 2. Arquitectura Tecnológica

- **Frontend**: Vue.js 3 (SPA) con Vite.
- **Backend**: Node.js con Express.
- **Base de Datos**: PostgreSQL con extensión PostGIS para datos espaciales.
- **Comunicación en Tiempo Real**: Socket.io (WebSockets).
- **Mapas**: Leaflet.js.

---

## 3. Especificación por Módulos

### 3.1 Módulo de Autenticación y Seguridad

**Objetivo**: Controlar el acceso y garantizar la integridad de la información según el rol del usuario.

- **Requerimientos Funcionales**:
  - Gestión de perfiles de usuario (Nombre, Email, Avatar).
  - Sistema de roles: Administrador, Supervisor, Conductor y Pasajero.
  - Cambio de contraseña y recuperación de acceso.
  - Control de sesiones activas.
- **Reglas de Negocio**:
  - Las contraseñas deben estar encriptadas con `bcrypt`.
  - Formato de email validado.
  - Soft-delete: Los usuarios se inactivan, nunca se borran físicamente si tienen historial.

### 3.2 Módulo de Gestión de Conductores

**Objetivo**: Administrar el personal operativo y validar sus competencias legales.

- **Datos Requeridos**: Cédula, teléfono, categoría de licencia, fecha de vencimiento de licencia y dirección.
- **Funcionalidades**:
  - Registro y actualización de conductores.
  - Monitoreo de disponibilidad (Available/Busy).
  - Activación/Inactivación según estado administrativo.
- **Reglas de Negocio**:
  - **Restricción de Seguridad**: Un conductor con licencia vencida no puede ser asignado a rutas activas.
  - Sincronización automática: Al inactivar un usuario, se debe retirar de la lista de conductores disponibles.

### 3.3 Módulo de Gestión de Flota (Buses)

**Objetivo**: Controlar el inventario de vehículos y el cumplimiento de requisitos legales.

- **Datos Críticos**: Placa, código interno AMB, capacidad, y fechas de documentos (SOAT, Tecnico-Mecánica, Seguros RCC/RCE).
- **Funcionalidades**:
  - Listado y búsqueda por placa o código.
  - Almacenamiento de fotos del vehículo.
- **Reglas de Negocio**:
  - **Gestión de Alertas**: El sistema debe resaltar buses cuyos documentos venzan en los próximos 30 días.
  - Estado Operativo: Solo buses marcados como "Activos" participan en la asignación de turnos.

### 3.4 Módulo de Rutas y GIS

**Objetivo**: Definir la infraestructura geográfica del servicio.

- **Funcionalidades**:
  - Dibujo de trazados geográficos (LineStrings).
  - Cálculo automático de distancia en kilómetros basado en el trazado.
  - Asignación de colores por ruta para diferenciación visual.
- **Reglas de Negocio**:
  - Integridad referencial: No se permite eliminar rutas con turnos históricos o activos.
  - Geometría validada: Los trazados deben tener al menos dos puntos de coordenadas.

### 3.5 Módulo de Operación (Turnos y Viajes)

**Objetivo**: Planificar y ejecutar la operación diaria.

- **Ciclo de Vida del Viaje**:
  1.  **Scheduled**: Planificado en el calendario.
  2.  **Active**: El bus está en movimiento y transmitiendo GPS.
  3.  **Completed**: El recorrido terminó satisfactoriamente.
  4.  **Cancelled**: El viaje fue anulado por el administrador.
- **Reglas de Negocio**:
  - Un bus solo puede estar asignado a una ruta y un conductor a la vez.
  - Cálculo de progreso en tiempo real basado en la ventana horaria asignada.

### 3.6 Monitoreo en Tiempo Real (Monitor Live)

**Objetivo**: Supervisión visual y operativa de toda la flota sobre el mapa de la ciudad.

- **Requerimientos Funcionales**:
  - **La plataforma debe permitir** visualizar la ubicación exacta de todos los buses en movimiento sobre un mapa interactivo en tiempo real.
  - **La aplicación facilitará al usuario** la activación o desactivación de capas de rutas específicas para optimizar el análisis visual del mapa.
  - **El software posibilitará** el centrado automático de la vista del mapa sobre el trazado completo de una ruta con un solo clic.
  - **La consola de monitoreo debe ofrecer** métricas rápidas y actualizadas sobre el conteo de buses y rutas activas en la jornada.
  - **BucaraBus integrará una búsqueda** instantánea de rutas, conductores o placas mediante una barra de filtrado inteligente en el panel lateral.
  - **La interfaz ayudará al supervisor a** identificar visualmente mediante íconos distintivos si un bus transmite GPS en vivo o si se encuentra en modo programado.
  - **El Monitor Live calculará y mostrará** el porcentaje de progreso de cada unidad basándose en la ventana horaria del turno asignado.
  - **La herramienta presentará resúmenes** de desempeño al finalizar cada trayecto, incluyendo velocidad máxima y distancia total recorrida.

- **Requerimientos No Funcionales**:
  - **La infraestructura debe garantizar** que las actualizaciones de posición GPS se reflejen en la pantalla en menos de un segundo mediante tecnología WebSockets.
  - **El motor de datos asegurará** la estabilidad del sistema procesando las coordenadas en vivo en la memoria del servidor para evitar saturar la base de datos.
  - **El diseño visual proporcionará** una experiencia fluida y estética, permitiendo colapsar los paneles de control para priorizar la visibilidad del mapa.
  - **La plataforma comunicará** de forma permanente el estado de conexión con el servidor de tiempo real a través de un indicador visual de conectividad.
  - **El núcleo geológico realizará** cálculos espaciales de alta precisión utilizando el estándar PostGIS para la medición de distancias y trazado de rutas.

---

## 4. Requerimientos No Funcionales

- **Seguridad**: Uso de JWT para autenticación de API.
- **Rendimiento**: Soporte para hasta 50 transmisiones GPS simultáneas con latencia < 2 segundos.
- **Escalabilidad**: El diseño de la base de datos permite añadir nuevas empresas de transporte sin modificar el esquema.
- **Accesibilidad**: Interfaz responsiva adaptable a dispositivos móviles (Apps de Conductor/Pasajero) y pantallas grandes (Dashboards).
