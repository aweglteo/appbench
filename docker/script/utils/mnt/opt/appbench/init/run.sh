#!/bin/bash

# Load Discourse environment
. /opt/appbench/init/env.sh

declare -a cmd=(
  "bundle" "exec" "rails" "server"
  "-p" "$DISCOURSE_PORT_NUMBER"
)

export RAILS_ENV="$DISCOURSE_ENV"
printf "Discourse starting ... "
exec "${cmd[@]}" "$@"
;