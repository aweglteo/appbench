#!/bin/bash
# start Redis-Server
redis-server /etc/redis/redis.conf &

# start Database process
/etc/init.d/postgresql start


# Ensuring profiling DB exists and is migrated
sudo -E -u discourse bundle exec rake db:create db:migrate

# Import middleware
sudo -E -u discourse bundle exec rake middleware

# Ensuring seeding DB data
sudo -E -u discourse bundle exec ruby appbench/seed.rb

# Ensuring executing assets precompiles
sudo -E -u discourse bundle exec rake assets:precompile

# start mailcatcher
mailcatcher --http-ip 0.0.0.0

# TEMP
touch tmp/pids/unicorn.pid && : > tmp/pids/unicorn.pid
mkdir stackprof
chown -R discourse result/ tmp/ stackprof/

if [ $APPBENCH_TARGET = "throughput" ]; then
  # run the benchmark
  sudo -E -u discourse ruby appbench/bench.rb
elif [ $APPBENCH_TARGET = "rprof" ]; then
  # run the rpro
  sudo -E -u discourse ENABLE_STACKPROF=1 ruby appbench/rprof.rb
fi

