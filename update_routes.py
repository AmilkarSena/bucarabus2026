import re

with open('api/routes/catalogs.routes.js', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Fix GET /insurance-types/admin
content = re.sub(
    r"SELECT id_insurance_type, type_name",
    r"SELECT id_insurance_type, tag_insurance AS code, type_name",
    content
)

# 2. Fix POST /insurance-types
content = re.sub(
    r"const \{ type_name, descrip_insurance, is_mandatory \} = req\.body",
    r"const { code, type_name, descrip_insurance, is_mandatory } = req.body",
    content
)
content = re.sub(
    r"if \(\!type_name\?\.trim\(\)\) \{",
    r"if (!type_name?.trim() || !code?.trim()) {\n      return res.status(400).json({ success: false, message: 'El código y el nombre son requeridos' })\n    }\n    if (false) {",
    content
)
content = re.sub(
    r"fun_create_insurance_type\(\$1, \$2, \$3\)', \[type_name,",
    r"fun_create_insurance_type($1, $2, $3, $4)', [code.toUpperCase(), type_name,",
    content
)
content = re.sub(
    r"data: \{ id_insurance_type: row\.out_id_type, type_name, descrip_insurance, is_mandatory, is_active: true \}",
    r"data: { id_insurance_type: row.out_id_type, code: code.toUpperCase(), type_name, descrip_insurance, is_mandatory, is_active: true }",
    content
)

# 3. Fix PUT /insurance-types/:id
content = re.sub(
    r"const \{ type_name, descrip_insurance, is_mandatory \} = req\.body\n    if \(\!type_name\?\.trim\(\)\)",
    r"const { code, type_name, descrip_insurance, is_mandatory } = req.body\n    if (!type_name?.trim() || !code?.trim())",
    content
)
content = re.sub(
    r"fun_update_insurance_type\(\$1, \$2, \$3, \$4\)', \[id, type_name,",
    r"fun_update_insurance_type($1, $2, $3, $4, $5)', [id, code.toUpperCase(), type_name,",
    content
)
content = re.sub(
    r"data: \{ id_insurance_type: row\.out_id_type, type_name: row\.out_name, descrip_insurance, is_mandatory, is_active: row\.out_is_active \}",
    r"data: { id_insurance_type: row.out_id_type, code: code.toUpperCase(), type_name: row.out_name, descrip_insurance, is_mandatory, is_active: row.out_is_active }",
    content
)

# 4. Fix GET /transit-docs/admin
content = re.sub(
    r"SELECT id_doc, name_doc",
    r"SELECT id_doc, tag_transit_doc AS code, name_doc",
    content
)

# 5. Fix POST /transit-docs
content = re.sub(
    r"const \{ name_doc, descrip_doc, is_mandatory, has_expiration \} = req\.body",
    r"const { code, name_doc, descrip_doc, is_mandatory, has_expiration } = req.body",
    content
)
content = re.sub(
    r"if \(\!name_doc\?\.trim\(\)\) \{",
    r"if (!name_doc?.trim() || !code?.trim()) {\n      return res.status(400).json({ success: false, message: 'El código y el nombre son requeridos' })\n    }\n    if (false) {",
    content
)
content = re.sub(
    r"fun_create_transit_doc_type\(\$1, \$2, \$3, \$4\)', \[name_doc,",
    r"fun_create_transit_doc_type($1, $2, $3, $4, $5)', [code.toUpperCase(), name_doc,",
    content
)
content = re.sub(
    r"data: \{ id_doc: row\.out_id_doc, name_doc, descrip_doc, is_mandatory, has_expiration, is_active: true \}",
    r"data: { id_doc: row.out_id_doc, code: code.toUpperCase(), name_doc, descrip_doc, is_mandatory, has_expiration, is_active: true }",
    content
)

# 6. Fix PUT /transit-docs/:id
content = re.sub(
    r"const \{ name_doc, descrip_doc, is_mandatory, has_expiration \} = req\.body\n    if \(\!name_doc\?\.trim\(\)\)",
    r"const { code, name_doc, descrip_doc, is_mandatory, has_expiration } = req.body\n    if (!name_doc?.trim() || !code?.trim())",
    content
)
content = re.sub(
    r"fun_update_transit_doc_type\(\$1, \$2, \$3, \$4, \$5\)', \[id, name_doc,",
    r"fun_update_transit_doc_type($1, $2, $3, $4, $5, $6)', [id, code.toUpperCase(), name_doc,",
    content
)
content = re.sub(
    r"data: \{ id_doc: row\.out_id_doc, name_doc: row\.out_name, descrip_doc, is_mandatory, has_expiration, is_active: row\.out_is_active \}",
    r"data: { id_doc: row.out_id_doc, code: code.toUpperCase(), name_doc: row.out_name, descrip_doc, is_mandatory, has_expiration, is_active: row.out_is_active }",
    content
)

with open('api/routes/catalogs.routes.js', 'w', encoding='utf-8') as f:
    f.write(content)
