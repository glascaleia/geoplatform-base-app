#!/bin/bash
# Database dello stack, tutti con PostGIS: gp (core, le tabelle le crea il war con hbm2ddl=update), jdbc_template (layer builder, con le
# tabelle di Spring Batch) e preview_gp (datastore del publisher). Gira dopo 10_postgis.sh dell'immagine.
set -euo pipefail

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-SQL
    CREATE DATABASE gp;
    CREATE DATABASE jdbc_template;
    CREATE DATABASE preview_gp;
SQL

for db in gp jdbc_template preview_gp; do
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$db" -c "CREATE EXTENSION IF NOT EXISTS postgis;"
done

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname jdbc_template -f /geoplatform-sql/jdbc-template-batch.sql
