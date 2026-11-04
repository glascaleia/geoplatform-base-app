# geoplatform-service.war (Spring 7, Jakarta EE 11): serve Tomcat 11. Il war lo prepara build-backend.sh.
FROM tomcat:11.0-jdk21-temurin

RUN rm -rf /usr/local/tomcat/webapps/* \
    && mkdir -p /etc/geoplatform /var/lib/geoplatform/geoportal /var/lib/geoplatform/importer

COPY geoplatform-service.war /usr/local/tomcat/webapps/geoplatform-service.war

# ehcache scrive in ./target rispetto alla cartella di lavoro
WORKDIR /usr/local/tomcat

# localhost:8081 -> geoserver:8080: vedi geoserver-forward.sh
RUN apt-get update && apt-get install -y --no-install-recommends socat && rm -rf /var/lib/apt/lists/*
COPY geoserver-forward.sh /usr/local/bin/geoserver-forward.sh
CMD ["/usr/local/bin/geoserver-forward.sh"]
