resource "aws_ses_template" "invitation" {
  name    = "gildarck-invitation"
  subject = "¡Bienvenido a GILDARCK! 📸"
  html    = file("${path.module}/templates/invitation.html")
  text    = "¡Hola {{name}}! Bienvenido a GILDARCK. Tu código temporal es: {{password}}. Accede en: https://dev.gildarck.com/auth/login"
}

resource "aws_ses_template" "password_reset" {
  name    = "gildarck-password-reset"
  subject = "Recuperar contraseña - GILDARCK 🔒"
  html    = file("${path.module}/templates/password-reset.html")
  text    = "Hola {{name}}, tu código de recuperación es: {{code}}. Accede en: https://dev.gildarck.com/auth/reset-password"
}

output "templates" {
  value = {
    invitation = aws_ses_template.invitation.name
    password_reset = aws_ses_template.password_reset.name
  }
}
