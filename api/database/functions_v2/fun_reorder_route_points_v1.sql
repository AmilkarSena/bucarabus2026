-- =============================================
-- FUNCIÓN: fun_reorder_route_points v1.0
-- Directorio: functions_v2
-- =============================================
-- Descripción:
--   Reordena todos los puntos de una ruta en tab_route_points_assoc
--   aplicando el nuevo orden recibido como array JSON.
--   Realiza la operación de forma atómica: si algún id_point no existe
--   en la ruta, hace ROLLBACK y retorna error.
--
--   Caso de uso principal:
--     - Después de un drag-and-drop en la UI para reordenar paradas.
--     - Después de eliminar un punto (compactar huecos).
--
--   El array worder_json debe contener TODOS los id_point activos de
--   la ruta en el nuevo orden deseado. Ejemplo:
--     '[{"id_point":3,"order":1},{"id_point":1,"order":2},{"id_point":5,"order":3}]'
--
--   Reglas de negocio (validar en backend antes de llamar):
--     - El array debe contener exactamente los mismos puntos que la ruta tiene actualmente.
--     - No puede quedar la ruta con menos de 2 puntos.
--
-- Parámetros (IN):
--   wid_route    tab_route_points_assoc.id_route%TYPE — ID de la ruta a reordenar
--   worder_json  TEXT                                  — JSON array [{id_point, order}]
--
-- Retorna (OUT):
--   success       BOOLEAN                              — TRUE si se reordenó correctamente
--   msg           TEXT                                 — Mensaje descriptivo
--   error_code    VARCHAR(50)                         — NULL si éxito; código si falla
--   updated_count INTEGER                              — Número de puntos reordenados
--
-- Códigos de error:
--   ROUTE_REORDER_POINT_NOT_FOUND — Algún id_point del array no pertenece a la ruta
--   ROUTE_REORDER_JSON_ERROR      — JSON malformado
--   ROUTE_REORDER_CHECK           — Algún order <= 0 (violación de CHECK)
--   ROUTE_REORDER_ORDER_CONFLICT  — Dos puntos con el mismo order (violación de PK)
--   ROUTE_REORDER_ERROR           — Error inesperado
--
-- Versión   : 1.0
-- Fecha     : 2026-03-16
-- =============================================

DROP FUNCTION IF EXISTS fun_reorder_route_points(SMALLINT, TEXT);

CREATE OR REPLACE FUNCTION fun_reorder_route_points(
  wid_route     tab_route_points_assoc.id_route%TYPE,
  worder_json   TEXT,

  -- Parámetros OUT
  OUT success        BOOLEAN,
  OUT msg            TEXT,
  OUT error_code     VARCHAR(50),
  OUT updated_count  INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_item        JSONB;
  v_id_point    tab_route_points_assoc.id_point%TYPE;
  v_new_order   tab_route_points_assoc.point_order%TYPE;
  v_rows        INTEGER;
  v_total       INTEGER := 0;
  -- Orden temporal POSITIVO alto para evitar conflictos de PK durante el UPDATE.
  -- Debe ser > 0 para satisfacer CHECK (point_order > 0).
  -- Usamos 10000 + original para garantizar que no colisione con orders normales (1..N).
  v_temp_base   SMALLINT := 10000;
BEGIN

  success       := FALSE;
  msg           := '';
  error_code    := NULL;
  updated_count := 0;

  -- Paso 1: Pasar todos los point_order a valores temporales altos
  -- para evitar conflictos de PK al actualizar en cascada.
  -- Ejemplo: order 1 → 10001, order 2 → 10002, etc. (todos > 0, todos únicos)
  UPDATE tab_route_points_assoc
  SET    point_order = (v_temp_base + point_order)
  WHERE  id_route = wid_route;

  GET DIAGNOSTICS v_total = ROW_COUNT;

  IF v_total = 0 THEN
    msg        := 'Ruta no encontrada o sin puntos asignados (ID: ' || wid_route || ')';
    error_code := 'ROUTE_REORDER_POINT_NOT_FOUND';
    RETURN;
  END IF;

  -- Paso 2: Aplicar el nuevo orden desde el JSON
  FOR v_item IN
    SELECT value FROM jsonb_array_elements(worder_json::JSONB)
  LOOP
    v_id_point  := (v_item->>'id_point')::SMALLINT;
    v_new_order := (v_item->>'order')::SMALLINT;

    UPDATE tab_route_points_assoc
    SET    point_order = v_new_order
    WHERE  id_route = wid_route
      AND  id_point = v_id_point;

    GET DIAGNOSTICS v_rows = ROW_COUNT;

    IF v_rows = 0 THEN
      msg        := 'Punto (ID: ' || v_id_point || ') no pertenece a la ruta (ID: ' || wid_route || ')';
      error_code := 'ROUTE_REORDER_POINT_NOT_FOUND';
      RAISE EXCEPTION '%', msg;   -- fuerza ROLLBACK del bloque completo
    END IF;

    updated_count := updated_count + 1;
  END LOOP;

  success := TRUE;
  msg     := updated_count || ' punto(s) de la ruta (ID: ' || wid_route || ') reordenados exitosamente';

EXCEPTION
  WHEN SQLSTATE '22023' OR SQLSTATE 'P0001' THEN
    -- RAISE EXCEPTION lanzado internamente (punto no encontrado)
    updated_count := 0;
  WHEN invalid_text_representation OR invalid_parameter_value THEN
    msg           := 'JSON de orden inválido: ' || SQLERRM;
    error_code    := 'ROUTE_REORDER_JSON_ERROR';
    updated_count := 0;
  WHEN check_violation THEN
    msg           := 'Valor de order inválido (debe ser > 0): ' || SQLERRM;
    error_code    := 'ROUTE_REORDER_CHECK';
    updated_count := 0;
  WHEN unique_violation THEN
    msg           := 'Conflicto de orden: dos puntos con el mismo order: ' || SQLERRM;
    error_code    := 'ROUTE_REORDER_ORDER_CONFLICT';
    updated_count := 0;
  WHEN OTHERS THEN
    msg           := 'Error inesperado: ' || SQLERRM;
    error_code    := 'ROUTE_REORDER_ERROR';
    updated_count := 0;
END;
$$;


-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_reorder_route_points(SMALLINT, TEXT) IS
'v1.0 — Reordena atómicamente los puntos de una ruta (tab_route_points_assoc). Usa valores temporales negativos para evitar conflictos de PK durante el UPDATE en cascada. Recibe el nuevo orden como JSON array [{id_point, order}].';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Reordenar 3 puntos de la ruta ID=1
-- Antes: punto 1 → posición 1, punto 2 → posición 2, punto 3 → posición 3
-- Después (drag-and-drop): punto 3 → posición 1, punto 1 → posición 2, punto 2 → posición 3
SELECT * FROM fun_reorder_route_points(
  1,
  '[{"id_point":3,"order":1},{"id_point":1,"order":2},{"id_point":2,"order":3}]'
);
-- success | msg                                          | error_code | updated_count
-- TRUE    | 3 punto(s) de la ruta (ID: 1) reordenados   | NULL       | 3

-- Error: punto 99 no pertenece a la ruta
SELECT * FROM fun_reorder_route_points(
  1,
  '[{"id_point":99,"order":1},{"id_point":1,"order":2}]'
);
-- success | msg                                                      | error_code                    | updated_count
-- FALSE   | Punto (ID: 99) no pertenece a la ruta (ID: 1)          | ROUTE_REORDER_POINT_NOT_FOUND | 0

-- Flujo recomendado desde el backend (después de un drag-and-drop):
--   const newOrder = points.map((p, i) => ({ id_point: p.id_point, order: i + 1 }))
--   pool.query(`SELECT * FROM fun_reorder_route_points($1, $2)`,
--              [id_route, JSON.stringify(newOrder)])

*/
