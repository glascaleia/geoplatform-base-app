# geoplatform-service.war (Spring 7, Jakarta EE 11): serve Tomcat 11. Il war lo prepara build-backend.sh.
FROM tomcat:11.0-jdk21-temurin

RUN rm -rf /usr/local/tomcat/webapps/* \
    && mkdir -p /etc/geoplatform /var/lib/geoplatform/geoportal /var/lib/geoplatform/importer

COPY geoplatform-service.war /usr/local/tomcat/webapps/geoplatform-service.war

# ehcache scrive in ./target rispetto alla cartella di lavoro
WORKDIR /usr/local/tomcat
