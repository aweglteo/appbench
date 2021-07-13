#!/bin/sh

cd /home/rubybuild/ruby
./autogen.sh
cd ../
cd build

../ruby/configure --prefix=/opt/devruby --enable-shared
make -j5
make install
