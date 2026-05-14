#!/bin/bash
# =============================================
# Script de Deployment de Funciones PostgreSQL
# Sistema BucaraBUS - Versión 2.0
# =============================================
# Descripción: Ejecuta todas las funciones en el orden correcto de dependencias
# Uso: ./deploy-functions.sh [dbname] [dbuser] [dbhost] [dbport]
# =============================================

# Configuración por defecto
DB_NAME="${1:-bucarabus_db}"
DB_USER="${2:-bucarabus_user}"
DB_HOST="${3:-localhost}"
DB_PORT="${4:-5432}"
SKIP_SCHEMA="${SKIP_SCHEMA:-false}"
VERBOSE="${VERBOSE:-false}"

# Colores
COLOR_SUCCESS='\033[0;32m'
COLOR_ERROR='\033[0;31m'
COLOR_WARNING='\033[0;33m'
COLOR_INFO='\033[0;36m'
COLOR_GRAY='\033[0;90m'
COLOR_RESET='\033[0m'

# Función para ejecutar archivo SQL
execute_sql_file() {
    local file_path="$1"
    local description="$2"
    
    if [ ! -f "$file_path" ]; then
        echo -e "${COLOR_ERROR}❌ ERROR: Archivo no encontrado: $file_path${COLOR_RESET}"
        return 1
    fi
    
    local file_name=$(basename "$file_path")
    echo -e "\n${COLOR_INFO}▶ Ejecutando: $file_name${COLOR_RESET}"
    if [ -n "$description" ]; then
        echo -e "${COLOR_GRAY}  $description${COLOR_RESET}"
    fi
    
    local psql_args="-h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f $file_path"
    
    if [ "$VERBOSE" = "true" ]; then
        psql_args="$psql_args -a"  # Echo all input
    else
        psql_args="$psql_args -q"  # Quiet mode
    fi
    
    if PGPASSWORD="$PGPASSWORD" psql $psql_args 2>&1; then
        echo -e "${COLOR_SUCCESS}  ✅ Éxito${COLOR_RESET}"
        return 0
    else
        echo -e "${COLOR_ERROR}  ❌ Error al ejecutar $file_name${COLOR_RESET}"
        return 1
    fi
}

# Banner
echo -e "${COLOR_INFO}"
cat << "EOF"

╔══════════════════════════════════════════════════════════╗
║                                                          ║
║       🚍 BucaraBUS - Deployment de Funciones v2.0       ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝

EOF
echo -e "${COLOR_RESET}"

echo -e "${COLOR_INFO}📊 Configuración:${COLOR_RESET}"
echo -e "${COLOR_GRAY}   Base de datos: $DB_NAME${COLOR_RESET}"
echo -e "${COLOR_GRAY}   Usuario:       $DB_USER${COLOR_RESET}"
echo -e "${COLOR_GRAY}   Host:          $DB_HOST${COLOR_RESET}"
echo -e "${COLOR_GRAY}   Puerto:        $DB_PORT${COLOR_RESET}"
echo ""

# Directorio de este script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Verificar que psql está disponible
if ! command -v psql &> /dev/null; then
    echo -e "${COLOR_ERROR}❌ ERROR: psql no está disponible en el PATH${COLOR_RESET}"
    echo -e "${COLOR_WARNING}   Instala PostgreSQL client o agrega psql al PATH${COLOR_RESET}"
    exit 1
fi

echo -e "${COLOR_SUCCESS}✅ psql encontrado: $(which psql)${COLOR_RESET}"

# Solicitar contraseña
echo -n "Contraseña para $DB_USER: "
read -s PGPASSWORD
export PGPASSWORD
echo ""

# Contador de éxitos/fallos
success_count=0
fail_count=0
skip_count=0
total_files=0

# Función auxiliar para ejecutar con descripción
execute_with_desc() {
    local file="$1"
    local desc="$2"
    local skip="${3:-false}"
    
    if [ "$skip" = "true" ]; then
        echo -e "\n${COLOR_WARNING}⏭ Omitiendo: $file${COLOR_RESET}"
        echo -e "${COLOR_GRAY}  (Usar SKIP_SCHEMA=false para incluir)${COLOR_RESET}"
        ((skip_count++))
        return 0
    fi
    
    ((total_files++))
    
    if execute_sql_file "$SCRIPT_DIR/$file" "$desc"; then
        ((success_count++))
        return 0
    else
        ((fail_count++))
        
        # Preguntar si continuar
        echo -e "\n${COLOR_WARNING}⚠ Hubo un error. ¿Deseas continuar? (s/n)${COLOR_RESET}"
        read -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[SsYy]$ ]]; then
            echo -e "\n${COLOR_ERROR}❌ Deployment cancelado por el usuario${COLOR_RESET}"
            exit 1
        fi
        return 1
    fi
}

# Orden de ejecución de funciones

# 1. ESQUEMA (opcional)
execute_with_desc "bd_bucarabus.sql" \
    "Esquema base de datos con tablas, índices y datos iniciales" \
    "$SKIP_SCHEMA"

# 2. FUNCIONES CREATE
execute_with_desc "fun_create_user.sql" \
    "Crear usuarios en el sistema"

execute_with_desc "fun_create_bus.sql" \
    "Crear buses en el catálogo"

execute_with_desc "fun_create_driver.sql" \
    "Crear conductores con detalles"

execute_with_desc "fun_create_route.sql" \
    "Crear rutas con geometría PostGIS"

execute_with_desc "fun_create_trip.sql" \
    "Crear turnos/viajes programados (2 funciones)"

# 3. FUNCIONES UPDATE
execute_with_desc "fun_update_user.sql" \
    "Actualizar datos de usuarios (nombre, avatar)"

execute_with_desc "fun_update_bus.sql" \
    "Actualizar datos de buses"

execute_with_desc "fun_update_driver.sql" \
    "Actualizar datos de conductores"

execute_with_desc "fun_update_route.sql" \
    "Actualizar metadatos de rutas"

execute_with_desc "fun_update_trip.sql" \
    "Actualizar turnos/viajes (2 funciones: update + set_bus)"

# 4. FUNCIONES DELETE
execute_with_desc "fun_delete_driver.sql" \
    "Eliminar/desactivar conductores"

execute_with_desc "fun_delete_route.sql" \
    "Eliminar/desactivar rutas"

execute_with_desc "fun_delete_trip.sql" \
    "Eliminar turnos/viajes (3 funciones)"

# 5. FUNCIONES ESPECIALES
execute_with_desc "fun_assign_driver.sql" \
    "Asignar/desasignar conductor a bus"

execute_with_desc "fun_toggle_bus_status.sql" \
    "Activar/desactivar buses"

# Resumen final
echo -e "${COLOR_INFO}"
cat << "EOF"

╔══════════════════════════════════════════════════════════╗
║                    RESUMEN FINAL                         ║
╚══════════════════════════════════════════════════════════╝

EOF
echo -e "${COLOR_RESET}"

echo -e "${COLOR_INFO}📊 Estadísticas:${COLOR_RESET}"
echo -e "${COLOR_GRAY}   Total archivos: $total_files${COLOR_RESET}"
echo -e "${COLOR_SUCCESS}   ✅ Éxitos:      $success_count${COLOR_RESET}"

if [ $fail_count -eq 0 ]; then
    echo -e "${COLOR_SUCCESS}   ❌ Fallos:       $fail_count${COLOR_RESET}"
else
    echo -e "${COLOR_ERROR}   ❌ Fallos:       $fail_count${COLOR_RESET}"
fi

echo -e "${COLOR_WARNING}   ⏭ Omitidos:     $skip_count${COLOR_RESET}"
echo ""

# Limpiar contraseña
unset PGPASSWORD

if [ $fail_count -eq 0 ] && [ $total_files -gt 0 ]; then
    echo -e "${COLOR_SUCCESS}🎉 ¡Deployment completado exitosamente!${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_INFO}📝 Próximos pasos:${COLOR_RESET}"
    echo -e "${COLOR_GRAY}   1. Verificar funciones: SELECT proname FROM pg_proc WHERE proname LIKE 'fun_%';${COLOR_RESET}"
    echo -e "${COLOR_GRAY}   2. Probar funciones CREATE con usuario del sistema (1735689600)${COLOR_RESET}"
    echo -e "${COLOR_GRAY}   3. Actualizar backend para usar INTEGER en user_create/user_update${COLOR_RESET}"
    echo -e "${COLOR_GRAY}   4. Ejecutar pruebas end-to-end${COLOR_RESET}"
    exit 0
elif [ $total_files -eq 0 ]; then
    echo -e "${COLOR_WARNING}⚠ No se ejecutaron archivos${COLOR_RESET}"
    exit 1
else
    echo -e "${COLOR_WARNING}⚠ Deployment completado con errores${COLOR_RESET}"
    echo -e "${COLOR_GRAY}   Revisa los mensajes de error arriba y corrige los problemas${COLOR_RESET}"
    exit 1
fi
