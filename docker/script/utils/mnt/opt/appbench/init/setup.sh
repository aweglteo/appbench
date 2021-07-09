#!/bin/bash

# Load Discourse environment
. /opt/appbench/init/env.sh

# Load database library
if [[ -f /opt/appbench/scripts/lib/libpostgresqlclient.sh ]]; then
    . /opt/appbench/scripts/lib/libpostgresqlclient.sh
elif [[ -f /opt/appbench/scripts/lib/libpostgresql.sh ]]; then
    . /opt/appbench/scripts/lib/libpostgresql.sh
fi


# Load libraries
. /opt/appbench/scripts/lib/libdiscourse.sh

# Load scripts
. /opt/appbench/scripts/setup/postgres.sh
. /opt/appbench/scripts/setup/initialize.sh


# Ensure PostgreSQL Client environment variables settings are valid
# postgresql_client_validate

# Ensure PostgreSQL Client is initialized
# postgresql_client_initialize

# discourse_validate

discourse_initialize

