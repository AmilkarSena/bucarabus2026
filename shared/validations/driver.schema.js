import { z } from 'zod';

export const driverSchema = z.object({
  id_driver: z
    .coerce
    .number({
      required_error: "La cédula es obligatoria",
      invalid_type_error: "La cédula debe ser un número",
    })
    .min(10000, "La cédula debe tener al menos 5 dígitos")
    .max(9999999999999, "La cédula es demasiado larga"),
  
  name_driver: z
    .string({ required_error: "El nombre es obligatorio" })
    .min(3, "El nombre debe tener al menos 3 caracteres")
    .max(100, "El nombre no puede exceder 100 caracteres"),
    
  license_exp: z
    .string({ required_error: "La fecha de vencimiento de licencia es obligatoria" })
    .refine((date) => !isNaN(Date.parse(date)), {
      message: "Formato de fecha inválido",
    }),

  id_eps: z
    .coerce
    .number({
      required_error: "Debes seleccionar una EPS",
      invalid_type_error: "Debes seleccionar una EPS",
    })
    .min(1, "Debes seleccionar una EPS"),

  id_arl: z
    .coerce
    .number({
      required_error: "Debes seleccionar una ARL",
      invalid_type_error: "Debes seleccionar una ARL",
    })
    .min(1, "Debes seleccionar una ARL"),

  email_driver: z
    .string()
    .email("El formato del correo es inválido")
    .max(150, "El correo es demasiado largo")
    .nullable()
    .optional()
    .or(z.literal(''))
    .transform(e => (e === '' || e === null) ? null : e),

  phone_driver: z
    .string()
    .regex(/^[0-9]{7,15}$/, "El teléfono debe contener entre 7 y 15 dígitos numéricos")
    .min(7, "El teléfono debe tener al menos 7 dígitos")
    .max(15, "El teléfono no puede exceder 15 dígitos")
    .nullable()
    .optional(),

  address_driver: z
    .string()
    .max(200, "La dirección no puede exceder 200 caracteres")
    .nullable()
    .optional(),

  gender_driver: z
    .enum(['M', 'F', 'O', 'SA'], {
      errorMap: () => ({ message: "Género seleccionado no es válido" })
    })
    .nullable()
    .optional()
    .default('SA'),

  license_cat: z
    .enum(['SA', 'C1', 'C2', 'C3'], {
      errorMap: () => ({ message: "Categoría de licencia no es válida" })
    })
    .nullable()
    .optional()
    .default('SA'),

  blood_type: z
    .enum(['SA', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'], {
      errorMap: () => ({ message: "Tipo de sangre no es válido" })
    })
    .nullable()
    .optional()
    .default('SA'),

  emergency_contact: z
    .string()
    .max(100, "El contacto no puede exceder 100 caracteres")
    .nullable()
    .optional(),

  emergency_phone: z
    .string()
    .max(15, "El teléfono no puede exceder 15 dígitos")
    .nullable()
    .optional(),

  birth_date: z
    .string()
    .optional()
    .or(z.literal(''))
    .nullable()
    .transform(e => (e === '' || e === null) ? null : e),

  date_entry: z
    .string()
    .nullable()
    .optional()
    .or(z.literal(''))
    .transform(e => (e === '' || e === null) ? null : e),

  id_status: z
    .coerce
    .number({ invalid_type_error: "Estado de conductor inválido" })
    .optional()
    .default(1),

  user_create: z.number().optional(),
  user_update: z.number().optional(),
});
