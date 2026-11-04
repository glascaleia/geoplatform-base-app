#!/usr/bin/env bash
# Configura GeoServer per lo sviluppo locale, dopo il primo avvio (i dati restano nel volume geoserver-data).
# Le transazioni WFS-T dell'editing arrivano dal servizio senza credenziali: con la regola di default di GeoServer
# (*.*.w = GROUP_ADMIN,ADMIN) i layer risultano "read-only". Qui la scrittura è aperta a tutti: solo per lo sviluppo.
set -euo pipefail

GEOSERVER="${GEOSERVER:-http://localhost:8081/geoserver}"

curl -sf -u admin:geoserver -X PUT -H 'Content-Type: application/json' \
     -d '{"*.*.r":"*","*.*.w":"*"}' "$GEOSERVER/rest/security/acl/layers"
echo "Regole dei layer di GeoServer:"
curl -sf -u admin:geoserver -H 'Accept: application/json' "$GEOSERVER/rest/security/acl/layers.json"
echo
