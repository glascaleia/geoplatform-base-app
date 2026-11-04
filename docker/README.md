# GeoPlatform in Docker

La base app e lo stack dei servizi, per provarla in locale:

| Container | Immagine | Porta sull'host | Cosa fa |
|---|---|---|---|
| `geoplatform-service` | `tomcat:11.0-jdk21-temurin` con `geoplatform-service.war` | 8080 | i servizi (`/geoplatform-service/core`, `jsonCore`, `layerBuilder`, `csvImporter`, `geocoding`, `wms`, `wfs`...) |
| `postgis` | `postgis/postgis:16-3.4` (amd64, emulata sui Mac arm64) | 5433 | database `gp` (core), `jdbc_template` (layer builder, con le tabelle di Spring Batch), `preview_gp` (publisher) |
| `geoserver` | `docker.osgeo.org/geoserver:2.28.4` (la versione `V28x` del connector) | 8081 | con l'estensione Importer e la risorsa JNDI `jdbc/postgres_layerbuilder` su `jdbc_template`; utente `admin`, password `geoserver` |
| `baseapp` | `tomcat:11.0-jdk21-temurin` con `baseapp.war` (nella radice) | 9393 | la base app GWT: http://localhost:9393/BaseApp.html |
| `mailpit` | `axllent/mailpit` | 8025 | le mail delle notifiche (`gp-mail.properties`), da leggere su http://localhost:8025 |

Le password nel compose e nei file di `backend/conf` sono solo per lo sviluppo locale.

## Prerequisiti

- Docker Desktop avviato.
- JDK 21 (gli script lo scelgono da soli con `/usr/libexec/java_home -v 21`).
- `geo-platform` e `gp_advanced_extensions` clonati accanto a `geoplatform-base-app`, con i moduli dei rami in uso
  installati nel repository Maven locale (il war si costruisce con `-pl` e prende gli altri moduli da lì).

## Avvio

```
./build-backend.sh                 # war con tutti i profili (-Dfull), schema di Spring Batch, .env con la chiave jasypt
./build-frontend.sh                # baseapp.war con la compilazione GWT completa
docker compose up -d --build
./bootstrap-core.sh                # solo la prima volta: account, progetti, layer e ACL del core
./geoserver-setup.sh               # solo la prima volta: scrittura dei layer aperta a tutti (editing WFS-T)
docker compose logs -f geoplatform-service   # fino a "Server startup in"
```

`bootstrap-core.sh` lancia `BootstrapInitializerTest` di `geoplatform-initializer` sul database `gp` (porta 5433):
**cancella e ricrea tutti i dati del core**. Gli account creati sono quelli del test: `admin`, `user` e `viewer`, con la password uguale al nome.
Le tabelle le crea il war all'avvio (`hbm2ddl=update`), oppure il test stesso se il war non è ancora partito.

Prove veloci:

```
curl http://localhost:8080/geoplatform-service/services
curl http://localhost:8080/geoplatform-service/layerBuilder/loadWorkspaces
curl -H "Content-Type: application/json" -d '{"lang":"it","address":"Via Pretoria Potenza"}' \
     http://localhost:8080/geoplatform-service/geocoding/nominatim/searchAddress
```

Per fermare tutto: `docker compose down` (i dati restano nei volumi); `docker compose down -v` cancella anche i volumi.

## Configurazione

- La configurazione del war sta nei file di `backend/conf`, montati in `/etc/geoplatform` e letti tramite la system
  property `GP_DATA_DIR`: ogni file sovrascrive solo le chiavi che contiene rispetto a quello del classpath.
  - `gp-ws.properties`: GeoServer interno (`http://geoserver:8080/geoserver`), cartella del geoportal, publisher su
    `postgis`, XMPP su `localhost` (la connessione fatta all'avvio viene rifiutata subito invece di aspettare il timeout).
  - `persistence-db.properties`: il core su PostgreSQL (`gp`) invece di HSQLDB.
  - `jdbc-template.properties`: il layer builder su `postgis/jdbc_template`.
  - `gp-mail.properties`: le mail a Mailpit. `SMTPMailSpringProperties` vuole una password non vuota.
- Le system property `GP_*` si passano in `CATALINA_OPTS` (il codice le legge con `System.getProperty`, non come
  variabili d'ambiente). `GP_PERSISTENCE_PBE_KEY` viene da `sys.props` di geo-platform tramite il `.env` che scrive
  `build-backend.sh`, che non va nel repository.
- La risorsa JNDI di GeoServer, che il layer builder usa per i datastore che crea, la scrive l'immagine dalle variabili
  `POSTGRES_*` nel `<Context>` di `server.xml`. Quel `<Context>` ha `override="true"`, quindi un `context.xml` montato
  in `conf/` verrebbe ignorato.
- GeoServer ha due indirizzi: `geoserver_url` (`http://geoserver:8080/geoserver`), con cui servizi e base app gli
  parlano dentro compose, e `geoserver_public_url` (`http://localhost:8081/geoserver`), che layer builder, file
  importer e CSV importer scrivono nei layer per le richieste WMS del browser. Senza `geoserver_public_url` si usa
  `geoserver_url`.
- Lo stesso indirizzo pubblico serve anche dai container: le transazioni WFS-T dell'editing partono dai servizi verso
  l'indirizzo del layer. Per questo i container `geoplatform-service` e `baseapp` inoltrano `localhost:8081` a
  `geoserver:8080` con `socat` (`geoserver-forward.sh`, uguale nelle due cartelle).
- Le transazioni WFS-T arrivano a GeoServer dal servizio senza credenziali: `geoserver-setup.sh` apre a tutti la
  scrittura dei layer (`*.*.w=*`), altrimenti GeoServer li considera in sola lettura. Solo per lo sviluppo.
- `default_wfs_datasource` (il solo server su cui il servizio accetta le transazioni WFS-T) è l'indirizzo pubblico
  `http://localhost:8081/geoserver/wfs`, perché il servizio lo confronta con l'indirizzo del layer.
- I servizi ammettono le chiamate da altre origini (CORS di CXF con `allowAllOrigins`).
- La base app legge `frontend/conf/gp-ws.properties` (stesso meccanismo di `GP_DATA_DIR`): le servlet raggiungono
  servizi e GeoServer dalla rete di compose (`geoplatform-service`, `geoserver`). Il browser invece chiama i servizi
  REST migrati a Domino su `http://localhost:8080/geoplatform-service`, la service root scritta nelle interfacce: per
  questo il backend pubblica la porta 8080 e serve il CORS.

## Problemi trovati al primo avvio (corretti nei rami `domino-rest`)

- `ehcache` 3.4.0, portato da `gt-geotiff` (`imageio-ext-cog-streams`) in `geoplatform-publisher-base-impl`, usa JAXB
  javax e nascondeva l'ehcache `jakarta` di Hibernate: `NoClassDefFoundError: javax/xml/bind/JAXBException`.
- FreeMarker 2.3.34 di `hibernate-reveng` vinceva sul 2.3.35 di `geoplatform-mail-support`
  (`NoSuchFieldError: VERSION_2_3_35`): la versione ora sta nel BOM `geoplatform-spring-dependency`.
- `loadWorkspaces` con GeoServer senza workspace: `NullPointerException` in `GPGeoserverLoadWorkspacesRequest`.
- `insert.sql` di `geoplatform-dao` (profilo `bootstrap-db`) non corrisponde più al modello: per i dati del core si usa
  `BootstrapInitializerTest`. Il database `gp` vuole PostGIS (colonne `geometry`).

## Da fare

- La service root dei client Domino in una configurazione (oggi `http://localhost:8080/geoplatform-service`), e poi
  nginx davanti, così base app e servizi stanno sulla stessa origine.
- I log del war sono molto verbosi (`logback.xml` con `debug="true"` e logger a trace) e alcuni scrivono chiavi e
  password: da ridurre con un `logback.xml` per il container.
