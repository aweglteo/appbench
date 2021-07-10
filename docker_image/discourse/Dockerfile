FROM debian:buster-slim

ENV PG_MAJOR 13
ENV RUBY_ALLOCATOR /usr/lib/libjemalloc.so.1
ENV RAILS_ENV profile
ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y gnupg sudo curl
RUN apt update && apt install -y fping

# TODO: check how it works
RUN sh -c "fping proxy && echo 'Acquire { Retries \"0\"; HTTP { Proxy \"http://proxy:3128\";}; };' > /etc/apt/apt.conf.d/40proxy && apt update || true"

RUN apt -y install software-properties-common
RUN apt-mark hold initscripts
RUN apt -y upgrade

RUN apt install -y locales locales-all
ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8

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
                       anacron wget \
                       psmisc vim whois brotli libunwind-dev \
                       libtcmalloc-minimal4 cmake \
                       pngcrush pngquant

RUN apt -y install postgresql-${PG_MAJOR} postgresql-client-${PG_MAJOR} \
                       postgresql-contrib-${PG_MAJOR} libpq-dev libreadline-dev

RUN sed -i -e 's/start -q anacron/anacron -s/' /etc/cron.d/anacron
RUN sed -i.bak 's/$ModLoad imklog/#$ModLoad imklog/' /etc/rsyslog.conf
RUN sed -i.bak 's/module(load="imklog")/#module(load="imklog")/' /etc/rsyslog.conf
RUN dpkg-divert --local --rename --add /sbin/initctl
RUN sh -c "test -f /sbin/initctl || ln -s /bin/true /sbin/initctl"

RUN cd / &&\
    apt -y install runit socat &&\
    mkdir -p /etc/runit/1.d &&\
    apt clean &&\
    rm -f /etc/apt/apt.conf.d/40proxy &&\
    locale-gen en_US &&\
    apt install -y nodejs &&\
    npm install -g terser &&\
    npm install -g uglify-js

ADD /rootfs/tmp/install-nginx /tmp/install-nginx
RUN /tmp/install-nginx

RUN apt -y install advancecomp jhead jpegoptim libjpeg-turbo-progs optipng

RUN mkdir /jemalloc-stable && cd /jemalloc-stable &&\
      wget https://github.com/jemalloc/jemalloc/releases/download/3.6.0/jemalloc-3.6.0.tar.bz2 &&\
      tar -xjf jemalloc-3.6.0.tar.bz2 && cd jemalloc-3.6.0 && ./configure --prefix=/usr && make && make install &&\
      cd / && rm -rf /jemalloc-stable

RUN mkdir /jemalloc-new && cd /jemalloc-new &&\
      wget https://github.com/jemalloc/jemalloc/releases/download/5.2.1/jemalloc-5.2.1.tar.bz2 &&\
      tar -xjf jemalloc-5.2.1.tar.bz2 && cd jemalloc-5.2.1 && ./configure --prefix=/usr --with-install-suffix=5.2.1 && make build_lib && make install_lib &&\
      cd / && rm -rf /jemalloc-new

RUN echo 'gem: --no-document' >> /usr/local/etc/gemrc &&\
    mkdir /src && cd /src && git clone https://github.com/sstephenson/ruby-build.git &&\
    cd /src/ruby-build && ./install.sh &&\
    cd / && rm -rf /src/ruby-build && (ruby-build 2.7.2 /usr/local)

RUN gem update --system

RUN gem install bundler --force &&\
    rm -rf /usr/local/share/ri/2.7.2/system &&\
    cd / && git clone https://github.com/discourse/pups.git

ADD /rootfs/tmp/install-redis /tmp/install-redis
RUN /tmp/install-redis

ADD /rootfs/tmp/install-imagemagick /tmp/install-imagemagick
RUN /tmp/install-imagemagick

# Validate install
RUN ruby -Eutf-8 -e "v = \`convert -version\`; %w{png tiff jpeg freetype heic}.each { |f| unless v.include?(f); STDERR.puts('no ' + f +  ' support in imagemagick'); exit(-1); end }"


# This tool allows us to disable huge page support for our current process
# since the flag is preserved through forks and execs it can be used on any
# process
ADD /rootfs/src/thpoff.c /src/thpoff.c
RUN gcc -o /usr/local/sbin/thpoff /src/thpoff.c && rm /src/thpoff.c

# clean up for docker squash
RUN   rm -fr /usr/share/man &&\
      rm -fr /usr/share/doc &&\
      rm -fr /usr/share/vim/vim74/tutor &&\
      rm -fr /usr/share/vim/vim74/doc &&\
      rm -fr /usr/share/vim/vim74/lang &&\
      rm -fr /usr/local/share/doc &&\
      rm -fr /usr/local/share/ruby-build &&\
      rm -fr /root/.gem &&\
      rm -fr /root/.npm &&\
      rm -fr /tmp/* &&\
      rm -fr /usr/share/vim/vim74/spell/en*


RUN mkdir -p /etc/runit/3.d

ADD /rootfs/etc/runit-1 /etc/runit/1
ADD /rootfs/etc/runit-1.d-cleanup-pids /etc/runit/1.d/cleanup-pids
ADD /rootfs/etc/runit-1.d-anacron /etc/runit/1.d/anacron
ADD /rootfs/etc/runit-1.d-00-fix-var-logs /etc/runit/1.d/00-fix-var-logs
ADD /rootfs/etc/runit-2 /etc/runit/2
ADD /rootfs/etc/runit-3 /etc/runit/3
ADD /rootfs/sbin/boot /sbin/boot

ADD /rootfs/etc/cron /etc/service/cron/run
ADD /rootfs/etc/rsyslog /etc/service/rsyslog/run
ADD /rootfs/etc/cron.d_anacron /etc/cron.d/anacron



# Install discourse
RUN useradd discourse -s /bin/bash -m -U &&\
    mkdir -p /var/www &&\
    cd /var/www &&\
    git clone --depth 1 https://github.com/discourse/discourse.git &&\
    cd discourse &&\
    git remote set-branches --add origin tests-passed &&\
    chown -R discourse:discourse /var/www/discourse &&\
    cd /var/www/discourse &&\
    sudo -u discourse bundle install --deployment --jobs 4 --without test development &&\
    bundle exec rake maxminddb:get &&\
    find /var/www/discourse/vendor/bundle -name tmp -type d -exec rm -rf {} +

RUN gem update bundler --force &&\
      cd /var/www/discourse &&\
      chown -R discourse . &&\
      rm -fr .bundle &&\
      sudo -u discourse git pull &&\
      sudo -u discourse bundle install --standalone --jobs=4

# Install discourse dependencies
RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add - &&\
    echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list &&\
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add - &&\
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list &&\
    apt update &&\
    apt install -y libgconf-2-4 libxss1 google-chrome-stable yarn nodejs &&\
    npm install -g eslint babel-eslint &&\
    cd /var/www/discourse && sudo -E -u discourse -H yarn install

RUN cd /var/www/discourse && sudo -E -u discourse -H bundle exec rake plugin:install_all_official &&\
    sudo -E -u discourse -H bundle exec rake plugin:install_all_gems && \
    chown -R discourse /var/run/postgresql

# Install benchmark tools
RUN apt-get install -y apache2-utils libsqlite3-dev

RUN gem install facter
RUN gem install mailcatcher

# reconfigure PostgreSQL template databases to use UTF-8
# otherwise rake db:create fails

# RUN pg_dropcluster --stop 9.5 main && pg_createcluster --start -e UTF-8 9.5 main

# create role "discourse"
RUN /etc/init.d/postgresql start &&\
    sleep 5 &&\
    sudo -u postgres createuser --superuser discourse

WORKDIR /var/www/discourse
COPY /scripts/bench /var/www/discourse/bench
COPY /rootfs/opt/appbench /opt/appbench

COPY /scripts/bench /var/www/discourse/bench

EXPOSE 3000

CMD [ "/opt/appbench/scripts/discourse/entrypoint.sh" ]
