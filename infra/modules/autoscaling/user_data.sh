#!/bin/bash
# User data script para instancias EC2 en el Auto Scaling Group

# Actualizar sistema
yum update -y

# Instalar herramientas básicas
yum install -y docker

# Iniciar Docker
systemctl start docker
systemctl enable docker

# Crear un contenedor simple de prueba que escuche en el puerto de la aplicación
# NOTA: Esto es solo un placeholder. En producción, reemplazar con tu aplicación real
docker run -d \
  --name app \
  --restart always \
  -p ${app_port}:8080 \
  -e PORT=8080 \
  nginx:alpine

# Health check básico (opcional)
# El health check del ALB verificará que el puerto responda
# En producción, configurar un health endpoint apropiado

echo "Aplicación iniciada en el puerto ${app_port}" >> /var/log/user-data.log
