# Definir la versión que quieres instalar
TERRAGRUNT_VERSION="v0.43.0"  # Cambia por la versión que necesites

# Detectar arquitectura
ARCH=$(uname -m)
case $ARCH in
    x86_64) ARCH="amd64" ;;
    arm64|aarch64) ARCH="arm64" ;;
    *) echo "Arquitectura no soportada: $ARCH"; exit 1 ;;
esac

# Detectar OS
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

# Descargar e instalar
curl -LO "https://github.com/gruntwork-io/terragrunt/releases/download/${TERRAGRUNT_VERSION}/terragrunt_${OS}_${ARCH}"

# Hacer ejecutable y mover a PATH
chmod +x terragrunt_${OS}_${ARCH}
sudo mv terragrunt_${OS}_${ARCH} /usr/local/bin/terragrunt

# Verificar instalación
terragrunt --version