
-- ==========================================
-- CAMBIAR ESTADO DE TIPO DE SEGURO
-- ==========================================
CREATE OR REPLACE FUNCTION fun_toggle_insurance_type(
    p_id_type tab_insurance_types.id_insurance_type%TYPE
)
RETURNS TABLE (
    success BOOLEAN,
    msg TEXT,
    error_code VARCHAR,
    out_id_type tab_insurance_types.id_insurance_type%TYPE,
    out_name tab_insurance_types.name_insurance%TYPE,
    out_is_active tab_insurance_types.is_active%TYPE
) AS $$
DECLARE
    v_name VARCHAR(50);
    v_new_active BOOLEAN;
BEGIN
    UPDATE tab_insurance_types
    SET is_active = NOT is_active
    WHERE id_insurance_type = p_id_type
    RETURNING name_insurance, is_active INTO v_name, v_new_active;

    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, 'Tipo de seguro no encontrado.'::TEXT, 'INSURANCE_TYPE_NOT_FOUND'::VARCHAR, NULL::SMALLINT, NULL::VARCHAR, NULL::BOOLEAN;
    ELSE
        RETURN QUERY SELECT TRUE, 'Estado actualizado.'::TEXT, NULL::VARCHAR, p_id_type, v_name, v_new_active;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY SELECT FALSE, SQLERRM::TEXT, 'DB_ERROR'::VARCHAR, NULL::SMALLINT, NULL::VARCHAR, NULL::BOOLEAN;
END;
$$ LANGUAGE plpgsql;
