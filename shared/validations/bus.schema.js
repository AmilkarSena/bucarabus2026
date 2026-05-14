import { z } from 'zod';

export const busSchema = z.object({
  plate_number: z
    .string({ required_error: "La placa es obligatoria" })
    .regex(/^[A-Z]{3}[0-9]{3}$/, "La placa debe tener 3 letras mayúsculas seguidas de 3 números (ej. ABC123)"),
    
  amb_code: z
    .string()
    .regex(/^([A-Z]{3}-[0-9]{4}|SA)$/, "El código AMB debe tener el formato AAA-1234 o ser 'SA'")
    .nullable()
    .optional()
    .default('SA')
    .transform(e => (!e || e.trim() === '') ? 'SA' : e),

  code_internal: z
    .string({ required_error: "El código interno es obligatorio" })
    .max(5, "El código interno no puede exceder 5 caracteres"),

  id_company: z
    .coerce
    .number({ required_error: "Debes seleccionar una empresa", invalid_type_error: "Empresa inválida" })
    .min(1, "Debes seleccionar una empresa"),

  id_brand: z
    .coerce
    .number()
    .nullable()
    .optional(),

  model_name: z
    .string()
    .max(50, "El modelo no puede exceder 50 caracteres")
    .nullable()
    .optional()
    .default('SIN MODELO')
    .transform(e => (!e || e.trim() === '') ? 'SIN MODELO' : e),

  model_year: z
    .coerce
    .number({ required_error: "El año del modelo es obligatorio", invalid_type_error: "El año debe ser un número" })
    .min(1990, "El año del modelo debe ser igual o superior a 1990"),

  capacity_bus: z
    .coerce
    .number({ required_error: "La capacidad es obligatoria", invalid_type_error: "La capacidad debe ser un número" })
    .min(1, "La capacidad debe ser mayor a 0")
    .max(70, "La capacidad máxima permitida es 70 pasajeros"),

  chassis_number: z
    .string()
    .max(50, "El número de chasis no puede exceder 50 caracteres")
    .nullable()
    .optional()
    .default('SIN CHASIS')
    .transform(e => (!e || e.trim() === '') ? 'SIN CHASIS' : e),

  color_bus: z
    .string()
    .max(30, "El color no puede exceder 30 caracteres")
    .nullable()
    .optional()
    .default('SIN COLOR')
    .transform(e => (!e || e.trim() === '') ? 'SIN COLOR' : e),

  color_app: z
    .string()
    .regex(/^#[0-9A-Fa-f]{6}$/, "El color para la app debe ser un código HEX (ej. #FF0000)")
    .nullable()
    .optional()
    .default('#CCCCCC')
    .transform(e => (!e || e.trim() === '') ? '#CCCCCC' : e),

  photo_url: z
    .string()
    .max(500, "La URL de la foto es muy larga")
    .nullable()
    .optional()
    .default('SIN FOTO')
    .transform(e => (!e || e.trim() === '') ? 'SIN FOTO' : e),

  gps_device_id: z
    .string()
    .max(20, "El ID del GPS no puede exceder 20 caracteres")
    .nullable()
    .optional()
    .transform(e => (e === '' || e === null) ? null : e),

  id_owner: z
    .coerce
    .number({ required_error: "El propietario es obligatorio", invalid_type_error: "Propietario inválido" })
    .min(1, "Debes seleccionar un propietario"),

  id_status: z
    .coerce
    .number({ invalid_type_error: "Estado inválido" })
    .optional()
    .default(1),

  is_active: z.boolean().optional().default(true),
  user_create: z.number().optional(),
  user_update: z.number().optional(),
});
