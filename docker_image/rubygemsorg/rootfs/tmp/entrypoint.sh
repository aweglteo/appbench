#!/bin/sh

# start PostgreSQL

/etc/init.d/postgresql start

# create dartabase
sudo -E -u rubygems RAILS_ENV=production bundle exec rails db:create db:migrate


# start rails application
# sudo -E -u rubygems RAILS_ENV=production bundle exec unicorn_rails -c config/unicorn.conf.rb

# TEMP
touch tmp/pids/unicorn.pid && : > tmp/pids/unicorn.pid
mkdir stackprof
chown -R rubygems result/ tmp/ stackprof/

if [ $APPBENCH_TARGET = "throughput" ]; then
  # run the benchmark
  sudo -E -u rubygems ruby appbench/bench.rb
elif [ $APPBENCH_TARGET = "rprof" ]; then
  # run the rpro
  sudo -E -u rubygems ENABLE_STACKPROF=1 ruby appbench/rprof.rb
fi

