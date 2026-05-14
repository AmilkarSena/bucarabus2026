-- ============================================
-- Insertar usuario Administrador
-- ============================================
-- Paso 1: genera el hash con bcrypt (factor 10) y pégalo abajo
-- Ejemplo node: require('bcryptjs').hashSync('TuPassword123', 10)
-- ============================================

SELECT * FROM fun_create_user(
    'admin@bucarabus.com',          -- wemail
    '$2b$10$AQUI_VA_TU_HASH',       -- wpassword_hash  ← reemplaza esto
    'Administrador Sistema',         -- wfull_name
    1,                               -- wid_gender  (1-4)
    '1990-01-01',                    -- wbirth_date
    '3000000000',                    -- wphone
    -1,                              -- wuser_create  (-1 = sistema)
    NULL                             -- wavatar_url (opcional)
);

-- ============================================
-- Paso 2: asignar rol Administrador (id_role = 4)
-- Usa el id_user que devolvió el SELECT anterior
-- ============================================
INSERT INTO tab_user_roles (id_user, id_role, is_active, user_create)
VALUES (
    <ID_USER_RESULTADO>,             -- ← pega el id_user del resultado
    4,                               -- Administrador
    TRUE,
    -1
);