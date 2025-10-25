terraform {
  source = "git@github.com:terraform-aws-modules/terraform-aws-ses.git//modules/template?ref=v6.1.0"
}

include "root" {
  path = find_in_parent_folders()
}

locals {
  vars = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  service_vars = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags = merge(local.service_vars.locals.tags, { name = "gildarck-ses-templates" })
}

inputs = {
  templates = {
    "gildarck-invitation" = {
      subject  = "¡Bienvenido a GILDARCK! 📸"
      html     = file("./templates/invitation.html")
      text     = "¡Hola {{name}}! Bienvenido a GILDARCK. Tu código temporal es: {{password}}. Accede en: https://dev.gildarck.com/auth/login"
    }
    "gildarck-password-reset" = {
      subject  = "Recuperar contraseña - GILDARCK 🔒"
      html     = file("./templates/password-reset.html")
      text     = "Hola {{name}}, tu código de recuperación es: {{code}}. Accede en: https://dev.gildarck.com/auth/reset-password"
    }
  }
  
  tags = local.tags
}
