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
. /opt/appbench/scripts/lib/libdiscoursesidekiq.sh

# Ensure Discourse environment variables are valid
# discourse_validate

# Ensure Discourse is initialized
discourse_sidekiq_initialize

