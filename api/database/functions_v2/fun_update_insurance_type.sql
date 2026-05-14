
-- ==========================================
-- ACTUALIZAR TIPO DE SEGURO
-- ==========================================
CREATE OR REPLACE FUNCTION fun_update_insurance_type(
    p_id_type tab_insurance_types.id_insurance_type%TYPE,
    p_tag tab_insurance_types.tag_insurance%TYPE,
    p_name tab_insurance_types.name_insurance%TYPE,
    p_descrip tab_insurance_types.descrip_insurance%TYPE,
    p_mandatory tab_insurance_types.is_mandatory%TYPE
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
    v_active BOOLEAN;
BEGIN
    UPDATE tab_insurance_types
    SET tag_insurance = p_tag,
        name_insurance = p_name,
        descrip_insurance = p_descrip,
        is_mandatory = p_mandatory
    WHERE id_insurance_type = p_id_type
    RETURNING is_active INTO v_active;

    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, 'Tipo de seguro no encontrado.'::TEXT, 'INSURANCE_TYPE_NOT_FOUND'::VARCHAR, NULL::SMALLINT, NULL::VARCHAR, NULL::BOOLEAN;
    ELSE
        RETURN QUERY SELECT TRUE, 'Tipo de seguro actualizado correctamente.'::TEXT, NULL::VARCHAR, p_id_type, p_name, v_active;
    END IF;
EXCEPTION
    WHEN unique_violation THEN
        RETURN QUERY SELECT FALSE, 'Ya existe un tipo de seguro con este nombre o tag.'::TEXT, 'INSURANCE_TYPE_UNIQUE_VIOLATION'::VARCHAR, NULL::SMALLINT, NULL::VARCHAR, NULL::BOOLEAN;
    WHEN OTHERS THEN
        RETURN QUERY SELECT FALSE, SQLERRM::TEXT, 'DB_ERROR'::VARCHAR, NULL::SMALLINT, NULL::VARCHAR, NULL::BOOLEAN;
END;
$$ LANGUAGE plpgsql;
