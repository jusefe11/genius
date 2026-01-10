# Dockerfile para la aplicación Genius
FROM node:18-alpine

WORKDIR /app

# Copiar archivos de dependencias
COPY package*.json ./

# Instalar dependencias
RUN npm install

# Copiar código fuente
COPY src/ ./src/

# Exponer puerto
EXPOSE 8080

# Comando para iniciar la aplicación
CMD ["npm", "start"]
