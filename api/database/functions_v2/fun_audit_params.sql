
-- =============================================
-- 3. fun_audit_params
-- =============================================
-- Exclusivo para tab_parameters.
-- Solo tiene user_update (no user_create).
-- Solo auditamos UPDATE: el INSERT es seed de admin.
-- =============================================

DROP FUNCTION IF EXISTS fun_audit_params() CASCADE;

CREATE OR REPLACE FUNCTION fun_audit_params()
RETURNS TRIGGER AS $$
BEGIN

  IF TG_OP = 'UPDATE' THEN

    IF NEW IS NOT DISTINCT FROM OLD THEN
      RETURN OLD;
    END IF;

    NEW.updated_at := CURRENT_TIMESTAMP;

    INSERT INTO tab_audit_log (table_name, record_id, operation, old_data, new_data, changed_by)
    VALUES (
      TG_TABLE_NAME,
      NEW.param_key,            -- PK de tab_parameters
      'U',
      to_jsonb(OLD),
      to_jsonb(NEW),
      NEW.user_update
    );

  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fun_audit_params IS
  'Trigger de auditoría exclusivo para tab_parameters.
   Solo procesa UPDATE (INSERT es seed de admin, sin user_create en la tabla).';
