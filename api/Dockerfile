FROM node:20-alpine

# Establecer el directorio de trabajo dentro del contenedor
WORKDIR /app

# Copiar los archivos de dependencias primero (por eficiencia)
COPY package*.json ./

# Instalar las dependencias
RUN npm install

# Copiar el resto del código de la API al contenedor
COPY . .

# Exponer el puerto que usa tu API (sabemos que usa el 3001 por tu código)
EXPOSE 3001

# Comando para iniciar la aplicación
CMD ["npm", "start"]
