-- ==========================================
-- CREAR TIPO DE DOCUMENTO DE TRANSITO
-- ==========================================
CREATE OR REPLACE FUNCTION fun_create_transit_doc_type(
    p_tag tab_transit_documents.tag_transit_doc%TYPE,
    p_name tab_transit_documents.name_doc%TYPE,
    p_descrip tab_transit_documents.descrip_doc%TYPE,
    p_mandatory tab_transit_documents.is_mandatory%TYPE,
    p_has_expiration tab_transit_documents.has_expiration%TYPE
)
RETURNS TABLE (
    success BOOLEAN,
    msg TEXT,
    error_code VARCHAR,
    out_id_doc tab_transit_documents.id_doc%TYPE
) AS $$
DECLARE
    v_id SMALLINT;
BEGIN
    INSERT INTO tab_transit_documents (tag_transit_doc, name_doc, descrip_doc, is_mandatory, is_active, has_expiration)
    VALUES (p_tag, p_name, p_descrip, p_mandatory, TRUE, p_has_expiration)
    RETURNING id_doc INTO v_id;

    RETURN QUERY SELECT TRUE, 'Tipo de documento creado correctamente.'::TEXT, NULL::VARCHAR, v_id;
EXCEPTION
    WHEN unique_violation THEN
        RETURN QUERY SELECT FALSE, 'Ya existe un tipo de documento con este nombre o tag.'::TEXT, 'TRANSIT_DOC_UNIQUE_VIOLATION'::VARCHAR, NULL::SMALLINT;
    WHEN OTHERS THEN
        RETURN QUERY SELECT FALSE, SQLERRM::TEXT, 'DB_ERROR'::VARCHAR, NULL::SMALLINT;
END;
$$ LANGUAGE plpgsql;