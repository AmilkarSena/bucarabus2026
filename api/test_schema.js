import { z } from 'zod';

const driverSchema = z.object({
  id_driver: z.coerce.number().min(10000).max(9999999999999),
  name_driver: z.string().min(3).max(100),
  license_exp: z.string().refine((date) => !isNaN(Date.parse(date))),
  id_eps: z.coerce.number().min(1),
  id_arl: z.coerce.number().min(1),
  email_driver: z.string().email().max(150).nullable().optional().or(z.literal('')).transform(e => (e === '' || e === null) ? null : e),
  phone_driver: z.string().min(7).max(15).nullable().optional(),
  address_driver: z.string().max(200).nullable().optional(),
  gender_driver: z.enum(['M', 'F', 'O', 'SA']).nullable().optional().default('SA'),
  license_cat: z.enum(['SA', 'C1', 'C2', 'C3']).nullable().optional().default('SA'),
  blood_type: z.enum(['SA', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']).nullable().optional().default('SA'),
  emergency_contact: z.string().max(100).nullable().optional(),
  emergency_phone: z.string().max(15).nullable().optional(),
  birth_date: z.string().optional().or(z.literal('')).nullable().transform(e => (e === '' || e === null) ? null : e),
  date_entry: z.string().nullable().optional().or(z.literal('')).transform(e => (e === '' || e === null) ? null : e),
  id_status: z.coerce.number().optional().default(1),
  user_create: z.number().optional(),
  user_update: z.number().optional(),
});

const body = {
  "id_driver": 26546565,
  "name_driver": "Carlos Fernando Montoya Diaz",
  "address_driver": null,
  "phone_driver": "3104032985",
  "email_driver": "andresreypro1995@gmail.com",
  "birth_date": null,
  "gender_driver": "SA",
  "license_cat": "C1",
  "license_exp": "2027-02-05",
  "id_eps": 10,
  "id_arl": 9,
  "blood_type": "SA",
  "emergency_contact": "carlos rivera Perez",
  "emergency_phone": null,
  "date_entry": "2026-05-14",
  "id_status": 1
};

const result = driverSchema.safeParse(body);
if (!result.success) {
  console.error("FAILED", JSON.stringify(result.error.issues, null, 2));
} else {
  console.log("SUCCESS");
}
