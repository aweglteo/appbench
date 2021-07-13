#!/bin/sh

gem update --system
gem install facter

cd /var/www/redmine/

bundle config set --local without 'development test'
bundle install --jobs 3 --retry 5 --path ./vendor/bundle
bundle config set --local without 'development test' && bundle clean --force

