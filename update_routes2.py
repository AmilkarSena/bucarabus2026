import re

with open('api/routes/catalogs.routes.js', 'r', encoding='utf-8') as f:
    content = f.read()

# Update GET /insurance-types/admin
content = re.sub(
    r"SELECT id_insurance_type, tag_insurance AS code, type_name,",
    r"SELECT id_insurance_type, tag_insurance AS code, name_insurance,",
    content
)

# Update POST /insurance-types
content = re.sub(
    r"const \{ code, type_name, descrip_insurance, is_mandatory \} = req\.body",
    r"const { code, name_insurance, descrip_insurance, is_mandatory } = req.body",
    content
)
content = re.sub(
    r"if \(\!type_name\?\.trim\(\) \|\| \!code\?\.trim\(\)\)",
    r"if (!name_insurance?.trim() || !code?.trim())",
    content
)
content = re.sub(
    r"fun_create_insurance_type\(\$1, \$2, \$3, \$4\)', \[code\.toUpperCase\(\), type_name,",
    r"fun_create_insurance_type($1, $2, $3, $4)', [code.toUpperCase(), name_insurance,",
    content
)
content = re.sub(
    r"data: \{ id_insurance_type: row\.out_id_type, code: code\.toUpperCase\(\), type_name, descrip_insurance,",
    r"data: { id_insurance_type: row.out_id_type, code: code.toUpperCase(), name_insurance, descrip_insurance,",
    content
)

# Update PUT /insurance-types/:id
content = re.sub(
    r"const \{ code, type_name, descrip_insurance, is_mandatory \} = req\.body\n    if \(\!type_name\?\.trim\(\) \|\| \!code\?\.trim\(\)\)",
    r"const { code, name_insurance, descrip_insurance, is_mandatory } = req.body\n    if (!name_insurance?.trim() || !code?.trim())",
    content
)
content = re.sub(
    r"fun_update_insurance_type\(\$1, \$2, \$3, \$4, \$5\)', \[id, code\.toUpperCase\(\), type_name,",
    r"fun_update_insurance_type($1, $2, $3, $4, $5)', [id, code.toUpperCase(), name_insurance,",
    content
)
content = re.sub(
    r"data: \{ id_insurance_type: row\.out_id_type, code: code\.toUpperCase\(\), type_name: row\.out_name, descrip_insurance,",
    r"data: { id_insurance_type: row.out_id_type, code: code.toUpperCase(), name_insurance: row.out_name, descrip_insurance,",
    content
)

with open('api/routes/catalogs.routes.js', 'w', encoding='utf-8') as f:
    f.write(content)
