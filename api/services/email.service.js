import nodemailer from 'nodemailer'
import dotenv from 'dotenv'
dotenv.config()

/**
 * Servicio de correo electrónico via Gmail SMTP.
 * Responsabilidad única: enviar emails.
 * La configuración se lee exclusivamente del .env para evitar credenciales en código.
 */

const transporter = nodemailer.createTransport({
  host:   'smtp.gmail.com',
  port:   465,
  secure: true,   // SSL/TLS
  auth: {
    user: process.env.GMAIL_USER,
    pass: process.env.GMAIL_APP_PASSWORD  // Contraseña de aplicación (no la cuenta)
  }
})

/**
 * Envía el correo de recuperación de contraseña.
 * @param {string} toEmail   - Email del destinatario
 * @param {string} resetUrl  - URL con el token de recuperación
 * @param {string} fullName  - Nombre del usuario (para personalizar el correo)
 */
async function sendPasswordResetEmail(toEmail, resetUrl, fullName) {
  const mailOptions = {
    from:    `"BucaraBus 🚌" <${process.env.GMAIL_USER}>`,
    to:      toEmail,
    subject: 'Recuperación de Contraseña — BucaraBus',
    html: `
      <!DOCTYPE html>
      <html lang="es">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
      </head>
      <body style="margin:0;padding:0;font-family:'Segoe UI',Arial,sans-serif;background:#f1f5f9;">
        <div style="max-width:520px;margin:40px auto;background:white;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.08);">
          <!-- Header -->
          <div style="background:linear-gradient(135deg,#667eea,#764ba2);padding:32px 24px;text-align:center;">
            <div style="font-size:48px;margin-bottom:8px;">🚌</div>
            <h1 style="color:white;margin:0;font-size:24px;font-weight:700;">BucaraBus</h1>
            <p style="color:rgba(255,255,255,0.8);margin:4px 0 0;font-size:13px;">Sistema de Gestión de Transporte Urbano</p>
          </div>

          <!-- Cuerpo -->
          <div style="padding:32px 24px;">
            <h2 style="color:#1e293b;margin:0 0 12px;font-size:20px;">Hola, ${fullName} 👋</h2>
            <p style="color:#475569;margin:0 0 24px;line-height:1.6;">
              Recibimos una solicitud para restablecer la contraseña de tu cuenta en BucaraBus.
              Haz clic en el botón de abajo para continuar. El enlace expira en <strong>1 hora</strong>.
            </p>

            <div style="text-align:center;margin:32px 0;">
              <a href="${resetUrl}"
                 style="display:inline-block;background:linear-gradient(135deg,#667eea,#764ba2);
                        color:white;text-decoration:none;padding:14px 32px;border-radius:8px;
                        font-weight:600;font-size:15px;">
                🔑 Restablecer Contraseña
              </a>
            </div>

            <p style="color:#94a3b8;font-size:12px;margin:0 0 8px;">
              Si no solicitaste este cambio, puedes ignorar este correo. Tu contraseña no cambiará.
            </p>
            <p style="color:#94a3b8;font-size:12px;margin:0;">
              Si el botón no funciona, copia este enlace en tu navegador:<br>
              <a href="${resetUrl}" style="color:#6366f1;word-break:break-all;">${resetUrl}</a>
            </p>
          </div>

          <!-- Footer -->
          <div style="background:#f8fafc;padding:16px 24px;text-align:center;border-top:1px solid #e2e8f0;">
            <p style="color:#94a3b8;font-size:11px;margin:0;">
              © ${new Date().getFullYear()} BucaraBus — Bucaramanga, Colombia
            </p>
          </div>
        </div>
      </body>
      </html>
    `
  }

  await transporter.sendMail(mailOptions)
}

export default { sendPasswordResetEmail }
