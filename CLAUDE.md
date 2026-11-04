# geoplatform-base-app

La base app GWT di geo-platform (`baseapp.war`, modulo `org.geosdi.geoplatform.gui.BaseApp`). Dipende dai moduli di
`../geo-platform` e `../gp_advanced_extensions` installati nel repository Maven locale, con le versioni del BOM di
`../geoplatform-dependencies`.

## Remote

- `upstream`: `geosdi/geoplatform-base-app`, il progetto del gruppo.
- `origin`: il fork personale.

## Commit

- Nei messaggi di commit e nelle descrizioni delle PR non citare mai Claude: niente riga `Co-Authored-By: Claude ...`
  né "Generated with Claude Code".
- Gli appunti di questo file vanno in commit a parte, mai insieme al codice; poi push. La memoria di Claude Code resta
  sul singolo Mac.

## Build

- Sempre JDK 21 (`export JAVA_HOME=$(/usr/libexec/java_home -v 21)`): con versioni più nuove i plugin non girano.
- La compilazione GWT si chiede a parte, perché il goal `compile` del `gwt-maven-plugin` nel pom è commentato:
  `mvn clean compile gwt:compile war:war -Dmaven.test.skip=true` (lo fa `docker/build-frontend.sh`). Poi `mvn clean`.
- La compilazione ignora 2 unità già rotte e non usate (`GPLayerBuilderFeatureStore` e
  `GPLayerBuilderFeatureAttributeStore` di `layer-builder-service-api`).

## Docker

Lo stack completo sta in `docker/` (ramo `docker`), con README: PostGIS, GeoServer 2.28.4, `geoplatform-service`
(porta 8080), base app (http://localhost:9393/BaseApp.html, `admin`/`admin`), Mailpit. Ordine al primo avvio:
`./build-backend.sh`, `./build-frontend.sh`, `docker compose up -d --build`, `./bootstrap-core.sh`,
`./geoserver-setup.sh`. Dopo una modifica a un modulo: `mvn clean install` del modulo, il `build-*.sh` del war che lo
contiene, `docker compose up -d --build <servizio>`. Una modifica a `backend/conf` basta un
`docker compose restart geoplatform-service`.

Decisioni prese (dettagli nel README di `docker/`):

- GeoServer ha due indirizzi: `geoserver_url` (`http://geoserver:8080/geoserver`, dentro compose) e
  `geoserver_public_url` (`http://localhost:8081/geoserver`), che layer builder, file importer e CSV importer
  scrivono nei layer e che `CheckDataSourceCommand` accetta per l'editing. I container Tomcat inoltrano
  `localhost:8081` a GeoServer (`geoserver-forward.sh`), così l'indirizzo pubblico funziona anche dai servizi.
- `default_wfs_datasource` = `http://localhost:8081/geoserver/wfs`: è il solo server su cui il servizio accetta
  transazioni WFS-T, confrontato con l'indirizzo del layer.
- La risorsa JNDI `jdbc/postgres_layerbuilder` la scrive l'immagine di GeoServer dalle variabili `POSTGRES_*`: il suo
  `<Context>` in `server.xml` ha `override="true"` e ignora un `context.xml` montato.
- La scrittura dei layer su GeoServer è aperta a tutti (`*.*.w=*`, `geoserver-setup.sh`), perché il servizio manda
  le transazioni WFS-T senza credenziali. Solo per lo sviluppo.

## Domino REST e domino-jackson

Le chiamate REST del client GWT (layer builder, file importer, CSV importer, geocoding del pannello WFS) usano Domino
REST e domino-jackson al posto di RestyGWT dal 2026-11-04 (rami `domino-rest`). Dettagli completi nei punti 1 e 2
dei "Lavori aperti" di `../geo-platform/CLAUDE.md`; qui quello che serve per la base app.

- Versioni nel BOM `geoplatform-gwt-dependency` (pom e `build.gradle`): `domino-rest` 2.0.2, `domino-jackson` 1.0.6,
  `elemental2` 1.3.2, GWT 2.13.1. RestyGWT è ancora nel BOM, da togliere quando si uniscono i rami.
- Le interfacce hanno `@RequestFactory(serviceRoot = "http://localhost:8080/geoplatform-service")`: il browser chiama
  i servizi lì, per questo in Docker il backend pubblica la porta 8080 e i servizi ammettono il CORS (punto 10 sotto).
- I sorgenti generati dai processor di Domino devono stare nei jar dei moduli client, perché il compilatore GWT della
  base app li legge da lì (`copy-generated-gwt-sources`, vedi geo-platform).
- domino-jackson 1.0.6 non trova `@JsonTypeInfo`/`@JsonSubTypes` sui supertipi: per `JDBCTableNameQueryParam` non
  scrive `"type"` e il server rifiuta `countLayerFeatures` e `loadLayerSchema` (500, `InvalidTypeIdException`).
  - Correzione mia sul fork: ramo `fix/subtypes-from-supertypes` di `../domino-jackson` (commit `58d497d`), issue
    [#101](https://github.com/DominoKit/domino-jackson/issues/101) e PR
    [#102](https://github.com/DominoKit/domino-jackson/pull/102) su `development`. Al 2026-11-04 aperte, senza
    commenti né revisioni, senza conflitti.
  - Da fare: seguire la revisione e correggere sul ramo del fork. Quando DominoKit rilascia, alzare
    `domino-jackson.version` nel BOM, reinstallare i moduli client, ricostruire con `build-frontend.sh` e riprovare
    i due metodi dalla UI.
  - Per provare prima il fork bisogna cambiare la versione nel BOM: `-Ddomino-jackson.version` da riga di comando
    non cambia un BOM importato. La versione del fork non è pubblicata da nessuna parte: se serve, va deciso dove
    (groupId e versione).
- domino-jackson non legge `Map<String, Object>`, `Object` né campi dichiarati come interfaccia senza
  `@JsonTypeInfo` (ignora `@JsonDeserialize`): per le risposte degli upload ci sono DTO del client
  (`FileImporterLayerResponse`, `CSVSchemaResponse`) convertiti nei tipi di prima. Legge gli enum per nome: il server
  (Jackson 3) li scrive con `toString()` se non hanno `@JsonValue`.
- Prova di riferimento: `prove/domino-rest-count-layer-features` nel ramo `domino-rest` di `gp_advanced_extensions`
  (14 test sulla JVM e 11 in GWT `-prod`, con README).

## Lavori aperti

Prova dalla UI della base app in Docker, iniziata il 2026-11-04 (punti 3 e 4 dei "Lavori aperti" di
`../geo-platform/CLAUDE.md`). Le correzioni stanno nei rami `domino-rest` di geo-platform e `gp_advanced_extensions`
e nel ramo `docker` di questo progetto, tutti pubblicati su `origin` e non ancora uniti a `spring-upgrade`.

**Prima di riprendere: Docker va ricostruito.** Il 2026-11-04 sera Docker è stato svuotato (container, volumi,
immagini, rete e cache di build cancellati, Docker Desktop spento). Vanno ricostruite le immagini
(`build-frontend.sh` e il war del servizio), riavviato il compose di `docker/` e rilanciato `bootstrap-core.sh`: i dati
di PostGIS, GeoServer e Importer non ci sono più, quindi anche workspace e layer creati nelle prove vanno rifatti.

Provato e funzionante:

- Login, progetti e albero dei layer.
- Layer builder: workspace, creazione del layer (tabella in `jdbc_template`, datastore JNDI e layer su GeoServer),
  messaggi d'errore leggibili (prima arrivava la pagina HTML di Tomcat con lo stack trace).
- Aggiunta di un server WMS da GetCapabilities (`http://localhost:8081/geoserver/wms`), dopo aver tolto `xercesImpl`
  dal war dei servizi.
- Editing WFS di un layer creato col layer builder: si apre senza tile rosa.

Corretto strada facendo (commit sui rami sopra): risorsa JNDI di GeoServer; mapper JAX-RS generico
(`GPGenericExceptionMapper`) nel layer builder, CSV importer e geocoding; "tabella già esistente" come 400;
messaggi d'errore estratti dal JSON nelle servlet (`GPRestErrorBody`) e nel client GWT (`GPRestErrorMessage`, anche
senza radice); `geoserver_public_url`; `CheckDataSourceCommand` con l'indirizzo pubblico; `xercesImpl` fuori dal war
dei servizi (rompeva ogni GetCapabilities WMS); messaggio del server sulle transazioni WFS fallite
(`GPTransactionService`); namespace dei workspace senza `:/`; vecchio `gwt-user` 2.0.3 escluso da `streetview`;
configurazione della stampa relativa in `web.xml`.

Da fare, in quest'ordine:

1. Editing WFS: verificare dalla UI il salvataggio di una feature (insert), poi modifica e cancellazione, e
   "Mostra tabella attributi". Ultimo errore prima delle correzioni: GeoServer rispondeva "layer is read-only".
2. Tile rosa nell'editing WFS di un layer aggiunto da GetCapabilities (con quelli del layer builder non succede): a
   GeoServer non arriva nessuna GetMap. Serve dal browser l'URL e lo status di una tile rosa. Lo sfondo della mappa
   WFS è `OSM.Mapnik` di OpenLayers 2 (`http://a.tile.openstreetmap.org/...`, che OSM reindirizza in https).
3. File importer ("Importa Kml"): la voce è protetta e `BootstrapInitializerTest` non crea il permesso
   `FILE_IMPORTER` (in `GuiComponentIDs` di `geoplatform-initializer` mancano anche altri componenti dei widget
   avanzati). Aggiungerlo e provare l'upload.
4. CSV importer: upload, schema e creazione del layer.
5. Geocoding del pannello WFS (servizio Domino `geocoding/nominatim`).
6. `countLayerFeatures` e `loadLayerSchema`: con domino-jackson 1.0.6 rispondono 500 (manca `"type"`), finché
   DominoKit non rilascia la PR [#102](https://github.com/DominoKit/domino-jackson/pull/102).
7. `/baseapp/remote_logging` risponde 404: il client GWT crea il `SimpleRemoteLogHandler` anche se
   `GeoPlatform.gwt.xml` lo spegne (non trovato chi lo riaccende). O si spegne davvero o si aggiunge la servlet,
   che servirebbe anche a leggere nei log gli errori del client.
8. `/http-bind` risponde 500: il proxy XMPP di `web.xml` punta a `150.145.141.173:7070`. Da spegnere o rendere
   configurabile.
9. Catalogo CSW: non provato dopo aver tolto `xercesImpl` (non usa classi di Xerces direttamente).
10. Service root dei client Domino (`http://localhost:8080/geoplatform-service`, scritta nelle interfacce) in una
    configurazione, poi nginx davanti, così base app e servizi stanno sulla stessa origine.
11. `logback.xml` meno verboso per i container (alcuni logger scrivono chiavi e password).
12. A prova finita, con l'ok di Peppino: unire i rami `domino-rest` (geo-platform, `gp_advanced_extensions`,
    `geoplatform-dependencies`) a `spring-upgrade`, togliere RestyGWT dal BOM, e decidere se unire il ramo `docker`.
