#!/bin/sh

# start PostgreSQL
/etc/init.d/postgresql start

# create dartabase
sudo -E -u redmine RAILS_ENV=production bundle exec rails db:create db:migrate

# TEMP
touch tmp/pids/unicorn.pid && : > tmp/pids/unicorn.pid
chown -R redmine result/ tmp/


if [ $APPBENCH_TARGET = "throughput" ]; then
  # run the benchmark
  sudo -E -u redmine ruby appbench/bench.rb
elif [ $APPBENCH_TARGET = "rprof" ]; then
  # run the rpro
  sudo -E -u redmine ENABLE_STACKPROF=1 ruby appbench/rprof.rb
fi
