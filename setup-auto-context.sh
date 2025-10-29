#!/bin/bash

# 🤖 SETUP AUTOMÁTICO - Ejecutar UNA VEZ para configurar

SHELL_RC="$HOME/.zshrc"
if [[ "$SHELL" == *"bash"* ]]; then
    SHELL_RC="$HOME/.bashrc"
fi

# Agregar hook automático al shell
cat >> "$SHELL_RC" << 'EOF'

# 🤖 GILDARCK AUTO-CONTEXT SYSTEM
gildarck_auto_context() {
    if [[ "$PWD" == *"gildarck"* ]]; then
        /Users/jhoam.morales/Documents/gildarck/infrastructure-iac-terragrunt/auto-context.sh "$BASH_COMMAND" &>/dev/null &
    fi
}

# Ejecutar antes de cada comando si estamos en directorio gildarck
if [[ "$SHELL" == *"zsh"* ]]; then
    preexec_functions+=(gildarck_auto_context)
else
    trap 'gildarck_auto_context' DEBUG
fi
EOF

echo "✅ Auto-context configurado en $SHELL_RC"
echo "🔄 Ejecuta: source $SHELL_RC"
echo "🤖 Ahora cada comando en directorio gildarck guardará contexto automáticamente"
