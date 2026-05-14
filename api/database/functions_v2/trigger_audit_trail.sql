
-- =============================================
-- 4. TRIGGERS
-- =============================================

-- ── tab_companies ─────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_audit_companies ON tab_companies;
CREATE TRIGGER trg_audit_companies
  BEFORE INSERT OR UPDATE OR DELETE ON tab_companies
  FOR EACH ROW EXECUTE FUNCTION fun_audit_full('id_company');

-- ── tab_bus_owners ────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_audit_bus_owners ON tab_bus_owners;
CREATE TRIGGER trg_audit_bus_owners
  BEFORE INSERT OR UPDATE OR DELETE ON tab_bus_owners
  FOR EACH ROW EXECUTE FUNCTION fun_audit_full('id_owner');

-- ── tab_drivers ───────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_audit_drivers ON tab_drivers;
CREATE TRIGGER trg_audit_drivers
  BEFORE INSERT OR UPDATE OR DELETE ON tab_drivers
  FOR EACH ROW EXECUTE FUNCTION fun_audit_full('id_driver');

-- ── tab_buses ─────────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_audit_buses ON tab_buses;
CREATE TRIGGER trg_audit_buses
  BEFORE INSERT OR UPDATE OR DELETE ON tab_buses
  FOR EACH ROW EXECUTE FUNCTION fun_audit_full('id_bus');

-- ── tab_bus_insurance (PK compuesta: id_bus + id_insurance_type) ──────────
DROP TRIGGER IF EXISTS trg_audit_bus_insurance ON tab_bus_insurance;
CREATE TRIGGER trg_audit_bus_insurance
  BEFORE INSERT OR UPDATE OR DELETE ON tab_bus_insurance
  FOR EACH ROW EXECUTE FUNCTION fun_audit_full('id_bus|id_insurance_type');

-- ── tab_bus_transit_docs (PK compuesta: id_doc + id_bus) ──────────────────
DROP TRIGGER IF EXISTS trg_audit_bus_transit_docs ON tab_bus_transit_docs;
CREATE TRIGGER trg_audit_bus_transit_docs
  BEFORE INSERT OR UPDATE OR DELETE ON tab_bus_transit_docs
  FOR EACH ROW EXECUTE FUNCTION fun_audit_full('id_doc|id_bus');

-- ── tab_routes (excluye path_route: geometría PostGIS LineString) ──────────
DROP TRIGGER IF EXISTS trg_audit_routes ON tab_routes;
CREATE TRIGGER trg_audit_routes
  BEFORE INSERT OR UPDATE OR DELETE ON tab_routes
  FOR EACH ROW EXECUTE FUNCTION fun_audit_full('id_route', 'path_route');

-- ── tab_route_points (excluye location_point: geometría PostGIS Point) ────
DROP TRIGGER IF EXISTS trg_audit_route_points ON tab_route_points;
CREATE TRIGGER trg_audit_route_points
  BEFORE INSERT OR UPDATE OR DELETE ON tab_route_points
  FOR EACH ROW EXECUTE FUNCTION fun_audit_full('id_point', 'location_point');

-- ── tab_parameters ────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_audit_parameters ON tab_parameters;
CREATE TRIGGER trg_audit_parameters
  BEFORE UPDATE ON tab_parameters
  FOR EACH ROW EXECUTE FUNCTION fun_audit_params();