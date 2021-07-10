#!/bin/bash

chmod -R +x /opt
/opt/appbench/init/setup.sh

printf "** Discourse setup starting **"

echo ""
exec "$@"
