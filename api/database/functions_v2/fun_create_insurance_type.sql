-- ==========================================
-- CREAR TIPO DE SEGURO
-- ==========================================
CREATE OR REPLACE FUNCTION fun_create_insurance_type(
    p_tag tab_insurance_types.tag_insurance%TYPE,
    p_name tab_insurance_types.name_insurance%TYPE,
    p_descrip tab_insurance_types.descrip_insurance%TYPE,
    p_mandatory tab_insurance_types.is_mandatory%TYPE
)
RETURNS TABLE (
    success BOOLEAN,
    msg TEXT,
    error_code VARCHAR,
    out_id_type tab_insurance_types.id_insurance_type%TYPE
) AS $$
DECLARE
    v_id SMALLINT;
BEGIN
    INSERT INTO tab_insurance_types (tag_insurance, name_insurance, descrip_insurance, is_mandatory, is_active)
    VALUES (p_tag, p_name, p_descrip, p_mandatory, TRUE)
    RETURNING id_insurance_type INTO v_id;

    RETURN QUERY SELECT TRUE, 'Tipo de seguro creado correctamente.'::TEXT, NULL::VARCHAR, v_id;
EXCEPTION
    WHEN unique_violation THEN
        RETURN QUERY SELECT FALSE, 'Ya existe un tipo de seguro con este nombre o tag.'::TEXT, 'INSURANCE_TYPE_UNIQUE_VIOLATION'::VARCHAR, NULL::SMALLINT;
    WHEN OTHERS THEN
        RETURN QUERY SELECT FALSE, SQLERRM::TEXT, 'DB_ERROR'::VARCHAR, NULL::SMALLINT;
END;
$$ LANGUAGE plpgsql;