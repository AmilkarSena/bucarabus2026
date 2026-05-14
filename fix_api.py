import re

with open('api/routes/catalogs.routes.js', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix POST /insurance-types
content = re.sub(
    r"router\.post\('/insurance-types'.*?const result = await pool\.query\('SELECT \* FROM fun_create_insurance_type.*?\)",
    r"router.post('/insurance-types', requirePermission(PERMISSIONS.CREATE_CATALOGS), async (req, res) => {\n    try {\n      const { type_name, descrip_insurance, is_mandatory } = req.body\n      if (!type_name?.trim()) {\n        return res.status(400).json({ success: false, message: 'El nombre es requerido' })\n      }\n      const result = await pool.query('SELECT * FROM fun_create_insurance_type($1, $2, $3)', [type_name, descrip_insurance || null, is_mandatory ?? true])",
    content, flags=re.DOTALL
)

# Fix PUT /insurance-types
content = re.sub(
    r"fun_update_insurance_type\(, , , \)",
    r"fun_update_insurance_type($1, $2, $3, $4)",
    content
)

# Fix PATCH /insurance-types toggle
content = re.sub(
    r"fun_toggle_insurance_type\(\)",
    r"fun_toggle_insurance_type($1)",
    content
)

# Fix POST /transit-docs
content = re.sub(
    r"router\.post\('/transit-docs'.*?const result = await pool\.query\('SELECT \* FROM fun_create_transit_doc_type.*?\)",
    r"router.post('/transit-docs', requirePermission(PERMISSIONS.CREATE_CATALOGS), async (req, res) => {\n    try {\n      const { name_doc, descrip_doc, is_mandatory, has_expiration } = req.body\n      if (!name_doc?.trim()) {\n        return res.status(400).json({ success: false, message: 'El nombre es requerido' })\n      }\n      const result = await pool.query('SELECT * FROM fun_create_transit_doc_type($1, $2, $3, $4)', [name_doc, descrip_doc || null, is_mandatory ?? true, has_expiration ?? true])",
    content, flags=re.DOTALL
)

# Fix PUT /transit-docs
content = re.sub(
    r"fun_update_transit_doc_type\(, , , , \)",
    r"fun_update_transit_doc_type($1, $2, $3, $4, $5)",
    content
)

# Fix PATCH /transit-docs toggle
content = re.sub(
    r"fun_toggle_transit_doc_type\(\)",
    r"fun_toggle_transit_doc_type($1)",
    content
)

with open('api/routes/catalogs.routes.js', 'w', encoding='utf-8') as f:
    f.write(content)
