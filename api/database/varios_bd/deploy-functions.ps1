#!/usr/bin/env pwsh
# =============================================
# Script de Deployment de Funciones PostgreSQL
# Sistema BucaraBUS - Versión 2.0
# =============================================
# Descripción: Ejecuta todas las funciones en el orden correcto de dependencias
# Uso: .\deploy-functions.ps1 [-DbName nombre] [-DbUser usuario] [-DbHost host] [-DbPort puerto]
# =============================================

param(
    [string]$DbName = "bucarabus_db",
    [string]$DbUser = "bucarabus_user",
    [string]$DbHost = "localhost",
    [int]$DbPort = 5432,
    [switch]$SkipSchema,
    [switch]$Verbose
)

# Colores para output
$ColorSuccess = "Green"
$ColorError = "Red"
$ColorWarning = "Yellow"
$ColorInfo = "Cyan"

# Función para ejecutar archivo SQL
function Invoke-SqlFile {
    param(
        [string]$FilePath,
        [string]$Description
    )
    
    if (-not (Test-Path $FilePath)) {
        Write-Host "❌ ERROR: Archivo no encontrado: $FilePath" -ForegroundColor $ColorError
        return $false
    }
    
    $fileName = Split-Path $FilePath -Leaf
    Write-Host "`n▶ Ejecutando: $fileName" -ForegroundColor $ColorInfo
    if ($Description) {
        Write-Host "  $Description" -ForegroundColor DarkGray
    }
    
    try {
        $env:PGPASSWORD = Read-Host "Contraseña para $DbUser" -AsSecureString | ConvertFrom-SecureString -AsPlainText
        
        $arguments = @(
            "-h", $DbHost,
            "-p", $DbPort,
            "-U", $DbUser,
            "-d", $DbName,
            "-f", $FilePath
        )
        
        if ($Verbose) {
            $arguments += "-a"  # Echo all input
        } else {
            $arguments += "-q"  # Quiet mode
        }
        
        $result = & psql @arguments 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✅ Éxito" -ForegroundColor $ColorSuccess
            if ($Verbose -and $result) {
                Write-Host $result -ForegroundColor DarkGray
            }
            return $true
        } else {
            Write-Host "  ❌ Error al ejecutar $fileName" -ForegroundColor $ColorError
            Write-Host $result -ForegroundColor $ColorError
            return $false
        }
    }
    catch {
        Write-Host "  ❌ Excepción: $_" -ForegroundColor $ColorError
        return $false
    }
    finally {
        $env:PGPASSWORD = $null
    }
}

# Banner
Write-Host @"

╔══════════════════════════════════════════════════════════╗
║                                                          ║
║       🚍 BucaraBUS - Deployment de Funciones v2.0       ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝

"@ -ForegroundColor $ColorInfo

Write-Host "📊 Configuración:" -ForegroundColor $ColorInfo
Write-Host "   Base de datos: $DbName" -ForegroundColor Gray
Write-Host "   Usuario:       $DbUser" -ForegroundColor Gray
Write-Host "   Host:          $DbHost" -ForegroundColor Gray
Write-Host "   Puerto:        $DbPort" -ForegroundColor Gray
Write-Host ""

# Directorio de este script
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Verificar que psql está disponible
$psqlPath = Get-Command psql -ErrorAction SilentlyContinue
if (-not $psqlPath) {
    Write-Host "❌ ERROR: psql no está disponible en el PATH" -ForegroundColor $ColorError
    Write-Host "   Instala PostgreSQL client o agrega psql al PATH" -ForegroundColor $ColorWarning
    exit 1
}

Write-Host "✅ psql encontrado: $($psqlPath.Source)" -ForegroundColor $ColorSuccess

# Orden de ejecución de funciones
$functionFiles = @(
    # 1. ESQUEMA (opcional, usar -SkipSchema para omitir)
    @{
        File = "bd_bucarabus.sql"
        Description = "Esquema base de datos con tablas, índices y datos iniciales"
        SkipIfFlag = $SkipSchema
    },
    
    # 2. FUNCIONES CREATE (dependen del esquema)
    @{
        File = "fun_create_user.sql"
        Description = "Crear usuarios en el sistema"
    },
    @{
        File = "fun_create_bus.sql"
        Description = "Crear buses en el catálogo"
    },
    @{
        File = "fun_create_driver.sql"
        Description = "Crear conductores con detalles"
    },
    @{
        File = "fun_create_route.sql"
        Description = "Crear rutas con geometría PostGIS"
    },
    @{
        File = "fun_create_trip.sql"
        Description = "Crear turnos/viajes programados (2 funciones)"
    },
    
    # 3. FUNCIONES UPDATE (dependen de CREATE)
    @{
        File = "fun_update_user.sql"
        Description = "Actualizar datos de usuarios (nombre, avatar)"
    },
    @{
        File = "fun_update_bus.sql"
        Description = "Actualizar datos de buses"
    },
    @{
        File = "fun_update_driver.sql"
        Description = "Actualizar datos de conductores"
    },
    @{
        File = "fun_update_route.sql"
        Description = "Actualizar metadatos de rutas"
    },
    @{
        File = "fun_update_trip.sql"
        Description = "Actualizar turnos/viajes (2 funciones: update + set_bus)"
    },
    
    # 4. FUNCIONES DELETE (dependen de UPDATE)
    @{
        File = "fun_delete_driver.sql"
        Description = "Eliminar/desactivar conductores"
    },
    @{
        File = "fun_delete_route.sql"
        Description = "Eliminar/desactivar rutas"
    },
    @{
        File = "fun_delete_trip.sql"
        Description = "Eliminar turnos/viajes (3 funciones)"
    },
    
    # 5. FUNCIONES ESPECIALES (asignaciones, toggles)
    @{
        File = "fun_assign_driver.sql"
        Description = "Asignar/desasignar conductor a bus"
    },
    @{
        File = "fun_toggle_bus_status.sql"
        Description = "Activar/desactivar buses"
    }
)

# Contador de éxitos/fallos
$successCount = 0
$failCount = 0
$skipCount = 0
$totalFiles = 0

# Ejecutar cada archivo
foreach ($item in $functionFiles) {
    $filePath = Join-Path $ScriptDir $item.File
    
    # Verificar si se debe omitir
    if ($item.SkipIfFlag) {
        Write-Host "`n⏭ Omitiendo: $($item.File)" -ForegroundColor $ColorWarning
        Write-Host "  (Usar -SkipSchema:`$false para incluir)" -ForegroundColor DarkGray
        $skipCount++
        continue
    }
    
    $totalFiles++
    
    if (Invoke-SqlFile -FilePath $filePath -Description $item.Description) {
        $successCount++
    } else {
        $failCount++
        
        # Preguntar si continuar
        Write-Host "`n⚠ Hubo un error. ¿Deseas continuar? (S/N)" -ForegroundColor $ColorWarning -NoNewline
        $response = Read-Host
        if ($response -notmatch '^[sS]') {
            Write-Host "`n❌ Deployment cancelado por el usuario" -ForegroundColor $ColorError
            break
        }
    }
}

# Resumen final
Write-Host @"

╔══════════════════════════════════════════════════════════╗
║                    RESUMEN FINAL                         ║
╚══════════════════════════════════════════════════════════╝

"@ -ForegroundColor $ColorInfo

Write-Host "📊 Estadísticas:" -ForegroundColor $ColorInfo
Write-Host "   Total archivos: $totalFiles" -ForegroundColor Gray
Write-Host "   ✅ Éxitos:      $successCount" -ForegroundColor $ColorSuccess
Write-Host "   ❌ Fallos:       $failCount" -ForegroundColor $(if ($failCount -eq 0) { $ColorSuccess } else { $ColorError })
Write-Host "   ⏭ Omitidos:     $skipCount" -ForegroundColor $ColorWarning
Write-Host ""

if ($failCount -eq 0 -and $totalFiles -gt 0) {
    Write-Host "🎉 ¡Deployment completado exitosamente!" -ForegroundColor $ColorSuccess
    Write-Host ""
    Write-Host "📝 Próximos pasos:" -ForegroundColor $ColorInfo
    Write-Host "   1. Verificar funciones: SELECT proname FROM pg_proc WHERE proname LIKE 'fun_%';" -ForegroundColor Gray
    Write-Host "   2. Probar funciones CREATE con usuario del sistema (1735689600)" -ForegroundColor Gray
    Write-Host "   3. Actualizar backend para usar INTEGER en user_create/user_update" -ForegroundColor Gray
    Write-Host "   4. Ejecutar pruebas end-to-end" -ForegroundColor Gray
    exit 0
} elseif ($totalFiles -eq 0) {
    Write-Host "⚠ No se ejecutaron archivos" -ForegroundColor $ColorWarning
    exit 1
} else {
    Write-Host "⚠ Deployment completado con errores" -ForegroundColor $ColorWarning
    Write-Host "   Revisa los mensajes de error arriba y corrige los problemas" -ForegroundColor Gray
    exit 1
}
