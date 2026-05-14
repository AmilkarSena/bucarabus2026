FROM eclipse-temurin:21-jre

WORKDIR /photon

# Descargar el binario de Photon directamente al contenedor
ADD https://github.com/komoot/photon/releases/download/1.1.0/photon-1.1.0.jar /photon/photon.jar

# Instalar herramientas: zstd (descompresión), python3 (filtro geográfico), curl
RUN apt-get update && apt-get install -y zstd python3 curl && rm -rf /var/lib/apt/lists/*

# Asegurar permisos y crear carpeta de datos
COPY filter_bbox.py /photon/filter_bbox.py
RUN chmod +x /photon/filter_bbox.py && chmod +x /photon/photon.jar && \
    mkdir -p /photon/photon_data

# Exponer el puerto por defecto de Photon
EXPOSE 2322

# Comando por defecto: arrancar el servidor usando la nueva sintaxis de la versión 1.x
ENTRYPOINT ["java", "-jar", "/photon/photon.jar", "serve", "-data-dir", "/photon", "-listen-ip", "0.0.0.0"]
