#!/bin/sh

# start PostgreSQL
# /etc/init.d/postgresql start

# create dartabase
# sudo -E -u redmine RAILS_ENV=production bundle exec rails db:create db:migrate

# start rails application
# sudo -E -u redmine RAILS_ENV=production bundle exec unicorn_rails -c config/unicorn.rb
