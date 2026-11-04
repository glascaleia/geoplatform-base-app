#!/usr/bin/env bash
# Popola il database gp del core (account admin/user/viewer, ruoli, progetti, layer, server e ACL dei componenti della
# GUI) con BootstrapInitializerTest di geoplatform-initializer. CANCELLA prima tutti i dati del core. Lo stack deve essere
# avviato (postgis sulla porta 5433).
set -euo pipefail

DOCKER_DIR="$(cd "$(dirname "$0")" && pwd)"
GEO_PLATFORM="${GEO_PLATFORM:-$DOCKER_DIR/../../geo-platform}"
INITIALIZER="geoplatform-services/geoplatform-core/geoplatform-initializer"

# sempre il JDK 21: con versioni più nuove lo spotless e i plugin del progetto non girano
export JAVA_HOME="$(/usr/libexec/java_home -v 21)"

cd "$GEO_PLATFORM"
# senza -Pdevelop: quel profilo salta la compilazione dei test
mvn clean test -pl "$INITIALIZER" -Dtest=BootstrapInitializerTest -Dsurefire.timeout=300 \
    -DGP_DATA_DIR="$DOCKER_DIR/core-bootstrap" | grep -E "Tests run:|BUILD|ERROR"
mvn -q clean -pl "$INITIALIZER"
