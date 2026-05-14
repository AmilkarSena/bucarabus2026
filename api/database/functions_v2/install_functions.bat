@echo off
setlocal enabledelayedexpansion

REM Cambia estos valores según tu instalación
set PGUSER=postgres
set PGPASSWORD=postgres123
set PGDATABASE=db_proynom
set PGHOST=localhost
set PGPORT=5432

for %%f in (*.sql) do (
    echo Ejecutando %%f...
    psql -U %PGUSER% -d %PGDATABASE% -h %PGHOST% -p %PGPORT% -f "%%f"
)

echo Importación completa.
pause
