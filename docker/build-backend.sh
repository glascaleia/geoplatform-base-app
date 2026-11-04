#!/usr/bin/env bash
# Costruisce geoplatform-service.war (tutti i profili, -Dfull) da ../../geo-platform e prepara i file generati:
# lo schema di Spring Batch per jdbc_template e il .env con la chiave jasypt
# della persistenza, letta da sys.props di geo-platform. Prima vanno installati i moduli dei rami in uso.
set -euo pipefail

DOCKER_DIR="$(cd "$(dirname "$0")" && pwd)"
GEO_PLATFORM="${GEO_PLATFORM:-$DOCKER_DIR/../../geo-platform}"
WEBAPP="geoplatform-services/geoplatform-ws-core/geoplatform-ws-webapp"

# sempre il JDK 21: con versioni più nuove lo spotless e i plugin del progetto non girano
export JAVA_HOME="$(/usr/libexec/java_home -v 21)"

cd "$GEO_PLATFORM"
mvn clean package -Dfull -Pdevelop -Dmaven.test.skip=true -pl "$WEBAPP" | grep -E "BUILD|ERROR|Building war"
cp "$WEBAPP/target/geoplatform-service.war" "$DOCKER_DIR/backend/"
mvn -q clean -Pdevelop -pl "$WEBAPP"

mkdir -p "$DOCKER_DIR/postgis/generated"
BATCH_JAR="$(unzip -l "$DOCKER_DIR/backend/geoplatform-service.war" | grep -oE 'WEB-INF/lib/spring-batch-core-[^ ]+\.jar')"
unzip -p "$DOCKER_DIR/backend/geoplatform-service.war" "$BATCH_JAR" > "$DOCKER_DIR/postgis/generated/spring-batch-core.jar"
unzip -p "$DOCKER_DIR/postgis/generated/spring-batch-core.jar" org/springframework/batch/core/schema-postgresql.sql \
    > "$DOCKER_DIR/postgis/generated/jdbc-template-batch.sql"
rm "$DOCKER_DIR/postgis/generated/spring-batch-core.jar"

PBE_KEY="$(grep -E '^GP_PERSISTENCE_PBE_KEY=' "$WEBAPP/src/main/resources/sys.props" | cut -d= -f2-)"
printf 'GP_PERSISTENCE_PBE_KEY=%s\n' "$PBE_KEY" > "$DOCKER_DIR/.env"

echo "Pronto: backend/geoplatform-service.war, postgis/generated/, .env"
