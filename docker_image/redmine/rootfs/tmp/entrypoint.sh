#!/bin/sh

# start PostgreSQL
/etc/init.d/postgresql start
sleep 5

if [ $APPBENCH_TARGET = "throughput" ]; then
  ruby appbench/bench.rb
elif [ $APPBENCH_TARGET = "rprof" ]; then
  # run the rpro
  ruby appbench/rprof.rb
elif [ -z $APPBENCH_TARGET ]; then
  bundle exec puma -w 3
fi
