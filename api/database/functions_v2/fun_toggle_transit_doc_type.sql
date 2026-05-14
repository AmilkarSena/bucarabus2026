
-- ==========================================
-- CAMBIAR ESTADO DE TIPO DE DOCUMENTO
-- ==========================================
CREATE OR REPLACE FUNCTION fun_toggle_transit_doc_type(
    p_id_doc tab_transit_documents.id_doc%TYPE
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
    v_name VARCHAR(100);
    v_new_active BOOLEAN;
BEGIN
    UPDATE tab_transit_documents
    SET is_active = NOT is_active
    WHERE id_doc = p_id_doc
    RETURNING name_doc, is_active INTO v_name, v_new_active;

    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, 'Tipo de documento no encontrado.'::TEXT, 'TRANSIT_DOC_NOT_FOUND'::VARCHAR, NULL::SMALLINT, NULL::VARCHAR, NULL::BOOLEAN;
    ELSE
        RETURN QUERY SELECT TRUE, 'Estado actualizado.'::TEXT, NULL::VARCHAR, p_id_doc, v_name, v_new_active;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY SELECT FALSE, SQLERRM::TEXT, 'DB_ERROR'::VARCHAR, NULL::SMALLINT, NULL::VARCHAR, NULL::BOOLEAN;
END;
$$ LANGUAGE plpgsql;
