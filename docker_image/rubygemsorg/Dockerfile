FROM debian:buster-slim

ENV PG_MAJOR 13
ENV RUBY_VERSION 2.7.2
ENV RAILS_ENV production
ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y gnupg sudo curl
RUN apt update && apt install -y fping

RUN apt -y install software-properties-common
RUN apt-mark hold initscripts
RUN apt -y upgrade

RUN apt install -y locales locales-all
ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8

RUN apt -y install nodejs

RUN curl https://apt.postgresql.org/pub/repos/apt/ACCC4CF8.asc | apt-key add -
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ buster-pgdg main" | \
        tee /etc/apt/sources.list.d/postgres.list
RUN curl --silent --location https://deb.nodesource.com/setup_15.x | sudo bash -
RUN apt -y update

RUN apt -y install --no-install-recommends git rsyslog logrotate cron ssh-client less
RUN apt -y install build-essential rsync \
                       libxslt-dev libcurl4-openssl-dev \
                       libssl-dev libyaml-dev libtool \
                       libxml2-dev gawk parallel \
                       postgresql-${PG_MAJOR} postgresql-client-${PG_MAJOR} \
                       postgresql-contrib-${PG_MAJOR} libpq-dev libreadline-dev \
                       wget psmisc vim whois brotli libunwind-dev \
                       libtcmalloc-minimal4 cmake \
                       pngcrush pngquant

RUN cd / &&\
    apt -y install runit socat &&\
    mkdir -p /etc/runit/1.d &&\
    apt clean &&\
    rm -f /etc/apt/apt.conf.d/40proxy &&\
    locale-gen en_US &&\
    apt install -y nodejs &&\
    npm install -g terser &&\
    npm install -g uglify-js

RUN apt install -y zlib1g-dev
RUN echo 'gem: --no-document' >> /usr/local/etc/gemrc &&\
    mkdir /src && cd /src && git clone https://github.com/sstephenson/ruby-build.git &&\
    cd /src/ruby-build && ./install.sh &&\
    cd / && rm -rf /src/ruby-build && (ruby-build $(echo $RUBY_VERSION) /usr/local)

RUN gem update --system

# Install rubygems
RUN useradd rubygems -s /bin/bash -m -U &&\
    mkdir -p /var/www &&\
    cd /var/www &&\
    git clone --depth 1 https://github.com/rubygems/rubygems.org.git &&\
    cd rubygems.org &&\
    chown -R rubygems:rubygems /var/www/rubygems.org &&\
    cd /var/www/rubygems.org &&\
    mkdir log

WORKDIR /var/www/rubygems.org
ADD https://s3-us-west-2.amazonaws.com/oregon.production.s3.rubygems.org/versions/versions.list /app/config/versions.list
ADD https://s3-us-west-2.amazonaws.com/oregon.production.s3.rubygems.org/stopforumspam/toxic_domains_whole.txt /app/vendor/toxic_domains_whole.txt

RUN mv /var/www/rubygems.org/config/database.yml.example /var/www/rubygems.org/config/database.yml

RUN bundle config set --local without 'development test' && bundle install --jobs 20 --retry 5

RUN RAILS_ENV=production RAILS_GROUPS=assets SECRET_KEY_BASE=1234 bin/rails assets:precompile
RUN bundle config set --local without 'development test assets' && bundle clean --force


# Install benchmark tools
RUN apt-get install -y apache2-utils libsqlite3-dev

RUN gem install facter

RUN chown -R rubygems /var/run/postgresql

# create role "rubygems"
RUN /etc/init.d/postgresql start &&\
    sleep 5 &&\
    sudo -u postgres -E psql --command "CREATE USER rubygems WITH SUPERUSER PASSWORD 'rubygems'";

ENV RAILS_SERVE_STATIC_FILES true

COPY /rootfs/tmp /opt/tmp
RUN chmod -R +x /opt/tmp

# copy setting files
COPY /approot/ /var/www/rubygems.org/
RUN chown -R rubygems:rubygems /var/www/rubygems.org 
RUN bundle install

EXPOSE 3000

CMD [ "/opt/tmp/entrypoint.sh" ]
