-- =============================================
-- Trigger: trg_check_driver_available
-- Descripción: Proteger consistencia del campo available
-- Evita que un conductor asignado sea marcado como disponible
-- =============================================

CREATE OR REPLACE FUNCTION trg_check_driver_available()
RETURNS TRIGGER AS $$
DECLARE
    v_assigned_bus VARCHAR(6);
BEGIN
    -- Si intentan cambiar available de FALSE a TRUE
    IF NEW.available = TRUE AND OLD.available = FALSE THEN
        -- Verificar si está asignado a algún bus
        SELECT plate_number INTO v_assigned_bus
        FROM tab_buses 
        WHERE id_user = NEW.id_user
          AND is_active = TRUE
        LIMIT 1;
        
        IF v_assigned_bus IS NOT NULL THEN
            RAISE EXCEPTION 'No se puede marcar como disponible: el conductor está asignado al bus % (ID conductor: %)', 
                            v_assigned_bus, NEW.id_user;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Eliminar triggers anteriores si existen
DROP TRIGGER IF EXISTS trg_driver_details_available_check ON tab_driver_details;

-- Crear trigger en tab_driver_details
CREATE TRIGGER trg_driver_details_available_check
BEFORE UPDATE OF available ON tab_driver_details
FOR EACH ROW 
WHEN (NEW.available IS DISTINCT FROM OLD.available)
EXECUTE FUNCTION trg_check_driver_available();

