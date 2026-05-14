FROM maptiler/tileserver-gl:latest

USER root

# Instalar Xvfb (pantalla virtual para renderizado GL headless) + herramientas de estilo
RUN apt-get update && apt-get install -y xvfb wget unzip curl && \
    mkdir -p /usr/src/app/styles && \
    wget -q https://github.com/openmaptiles/positron-gl-style/archive/refs/heads/master.zip \
      -O /tmp/positron.zip && \
    unzip -q /tmp/positron.zip -d /tmp/ && \
    mv /tmp/positron-gl-style-master /usr/src/app/styles/positron && \
    wget -q https://openmaptiles.github.io/positron-gl-style/sprite.json -O /usr/src/app/styles/positron/sprite.json && \
    wget -q https://openmaptiles.github.io/positron-gl-style/sprite.png -O /usr/src/app/styles/positron/sprite.png && \
    wget -q https://openmaptiles.github.io/positron-gl-style/sprite@2x.json -O /usr/src/app/styles/positron/sprite@2x.json && \
    wget -q https://openmaptiles.github.io/positron-gl-style/sprite@2x.png -O /usr/src/app/styles/positron/sprite@2x.png && \
    sed -i 's|"url": ".*"|"url": "mbtiles://openmaptiles"|g' /usr/src/app/styles/positron/style.json && \
    sed -i 's|"glyphs": ".*"|"glyphs": "{fontstack}/{range}.pbf"|g' /usr/src/app/styles/positron/style.json && \
    sed -i -E 's/"text-font": \[[^\]]+\]/"text-font": ["Noto Sans Regular"]/g' /usr/src/app/styles/positron/style.json && \
    sed -i 's|"rgb(242,243,240)"|"rgb(243, 246, 244)"|g' /usr/src/app/styles/positron/style.json && \
    sed -i 's|"rgb(230, 233, 229)"|"rgb(235, 240, 231)"|g' /usr/src/app/styles/positron/style.json && \
    sed -i 's|"rgb(194, 200, 202)"|"rgb(212, 218, 223)"|g' /usr/src/app/styles/positron/style.json && \
    sed -i 's|"rgb(234, 234, 230)"|"rgb(243, 246, 244)"|g' /usr/src/app/styles/positron/style.json && \
    sed -i 's|"rgb(220,224,220)"|"rgb(235, 240, 231)"|g' /usr/src/app/styles/positron/style.json && \
    sed -i 's|"hsl(0, 0%, 88%)"|"#fff"|g' /usr/src/app/styles/positron/style.json && \
    sed -i 's|"hsla(0, 0%, 85%, 0.69)"|"#fff"|g' /usr/src/app/styles/positron/style.json && \
    sed -i 's|"hsla(0, 0%, 85%, 0.69)"|"#fff"|g' /usr/src/app/styles/positron/style.json && \
    sed -i '/"id": "place_suburb"/,/visibility/ s/"visible"/"none"/' /usr/src/app/styles/positron/style.json && \
    sed -i '/"id": "place_village"/,/visibility/ s/"visible"/"none"/' /usr/src/app/styles/positron/style.json && \
    sed -i '/"id": "place_hamlet"/,/visibility/ s/"visible"/"none"/' /usr/src/app/styles/positron/style.json && \
    sed -i '/"id": "place_other"/,/visibility/ s/"visible"/"none"/' /usr/src/app/styles/positron/style.json && \
    sed -i 's|"sprite": ".*"|"sprite": "styles/positron/sprite"|g' /usr/src/app/styles/positron/style.json && \
    rm /tmp/positron.zip && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Copiar la configuración
COPY config.json /usr/src/app/config.json

# Script de arranque: inicia Xvfb primero, luego el tile server
RUN printf '#!/bin/bash\n\
Xvfb :99 -screen 0 1024x768x24 -nolisten tcp &\n\
export DISPLAY=:99\n\
sleep 1\n\
exec node /usr/src/app/src/main.js "$@"\n' > /entrypoint.sh && chmod +x /entrypoint.sh

EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
CMD ["--config", "/usr/src/app/config.json"]
