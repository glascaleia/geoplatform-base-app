#!/bin/sh
# Avvio dei container Tomcat di servizi e base app: localhost:8081 inoltrato a geoserver:8080, così l'indirizzo
# pubblico di GeoServer scritto nei layer (http://localhost:8081/geoserver, quello che usa il browser) funziona anche
# per le richieste che partono da qui, per esempio le transazioni WFS-T del layer.
socat TCP-LISTEN:8081,fork,reuseaddr TCP:geoserver:8080 &
exec catalina.sh run
