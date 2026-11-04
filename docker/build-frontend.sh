#!/usr/bin/env bash
# Costruisce baseapp.war (compilazione GWT completa) da questo progetto e lo copia in frontend/. Prima vanno installati
# nel repository Maven locale i moduli di geo-platform e gp_advanced_extensions dei rami in uso.
set -euo pipefail

DOCKER_DIR="$(cd "$(dirname "$0")" && pwd)"

# sempre il JDK 21: con versioni più nuove i plugin del progetto non girano
export JAVA_HOME="$(/usr/libexec/java_home -v 21)"

cd "$DOCKER_DIR/.."
# il goal compile del gwt-maven-plugin nel pom è commentato: la compilazione GWT si chiede a parte
mvn clean compile gwt:compile war:war -Dmaven.test.skip=true | grep -E "BUILD|ERROR|Compiling module|Building war"
cp target/baseapp.war "$DOCKER_DIR/frontend/"
mvn -q clean

echo "Pronto: frontend/baseapp.war"
