# Appbench

Easy measure rails benchmark in your developing ruby

## build your ruby
!! work in progress !!
```
git clone https://github.com/ruby/ruby ./ruby/dev_ruby/ruby
docker-compose -f docker-compose.rubybuild.yml build
docker-compose -f docker-compose.rubybuild.yml up
```
your ruby is built, and shared with app containers in "/home/devruby/bin/ruby" 

## build app enviroment

```
ruby run.rb build -a [ discourse | rubygems | redmine ]
```

## exec bench

build app enviroment before executing benchmark 

```
ruby run.rb up -a [ discourse | rubygems | redmine ] -m [ throughput | rprof ]
```

## Dependencies

- Docker
- Docker Compose
