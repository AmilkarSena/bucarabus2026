-- =============================================
-- MIGRACIÓN: Permitir paradas duplicadas por ruta
-- Fecha: 2026-03-24
-- Descripción:
--   Elimina el constraint UNIQUE (id_route, id_point) de tab_route_points_assoc
--   para permitir que una misma parada aparezca más de una vez en la misma ruta
--   (p.ej. rutas que pasan dos veces por la misma parada).
--   La PK (id_route, point_order) sigue siendo la clave de unicidad real.
-- =============================================

ALTER TABLE tab_route_points_assoc
  DROP CONSTRAINT IF EXISTS uq_route_points_assoc_point;
