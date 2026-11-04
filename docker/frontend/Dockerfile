# baseapp.war (GWT 2.13, Spring 7): Tomcat 11 come il backend. Il war lo prepara build-frontend.sh.
FROM tomcat:11.0-jdk21-temurin

RUN rm -rf /usr/local/tomcat/webapps/* && mkdir -p /etc/geoplatform

# nella radice, come con jetty:run: la pagina è /BaseApp.html e le servlet stanno sotto /baseapp
COPY baseapp.war /usr/local/tomcat/webapps/ROOT.war

WORKDIR /usr/local/tomcat
