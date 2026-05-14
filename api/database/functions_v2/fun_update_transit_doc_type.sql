
-- ==========================================
-- ACTUALIZAR TIPO DE DOCUMENTO DE TRANSITO
-- ==========================================
CREATE OR REPLACE FUNCTION fun_update_transit_doc_type(
    p_id_doc tab_transit_documents.id_doc%TYPE,
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
    out_id_doc tab_transit_documents.id_doc%TYPE,
    out_name tab_transit_documents.name_doc%TYPE,
    out_is_active tab_transit_documents.is_active%TYPE
) AS $$
DECLARE
    v_active BOOLEAN;
BEGIN
    UPDATE tab_transit_documents
    SET tag_transit_doc = p_tag,
        name_doc = p_name,
        descrip_doc = p_descrip,
        is_mandatory = p_mandatory,
        has_expiration = p_has_expiration
    WHERE id_doc = p_id_doc
    RETURNING is_active INTO v_active;

    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, 'Tipo de documento no encontrado.'::TEXT, 'TRANSIT_DOC_NOT_FOUND'::VARCHAR, NULL::SMALLINT, NULL::VARCHAR, NULL::BOOLEAN;
    ELSE
        RETURN QUERY SELECT TRUE, 'Tipo de documento actualizado correctamente.'::TEXT, NULL::VARCHAR, p_id_doc, p_name, v_active;
    END IF;
EXCEPTION
    WHEN unique_violation THEN
        RETURN QUERY SELECT FALSE, 'Ya existe un tipo de documento con este nombre o tag.'::TEXT, 'TRANSIT_DOC_UNIQUE_VIOLATION'::VARCHAR, NULL::SMALLINT, NULL::VARCHAR, NULL::BOOLEAN;
    WHEN OTHERS THEN
        RETURN QUERY SELECT FALSE, SQLERRM::TEXT, 'DB_ERROR'::VARCHAR, NULL::SMALLINT, NULL::VARCHAR, NULL::BOOLEAN;
END;
$$ LANGUAGE plpgsql;