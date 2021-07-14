#!/bin/sh

# start PostgreSQL
/etc/init.d/postgresql start


gem update --system
gem install facter
gem install stackprof

bundle config set --local without 'development test'
bundle install --jobs 3 --retry 5 --path ./vendor/bundle
bundle config set --local without 'development test' && bundle clean --force

# create dartabase
RAILS_ENV=production bundle exec rails db:create db:migrate

# TEMP
chown -R redmine result/ tmp/

if [ $APPBENCH_TARGET = "throughput" ]; then
  ruby appbench/bench.rb
elif [ $APPBENCH_TARGET = "rprof" ]; then
  # run the rpro
  ruby appbench/rprof.rb
fi
