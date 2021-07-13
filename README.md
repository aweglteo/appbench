# Appbench
Easy measure rails benchmark in your developing ruby

## How to use

```
git clone https://github.com/aweglteo/appbench
```

then, put your ruby in `<project_root>/ruby/rubybuild/ruby/`.
example 
```
git clone https://github.com/ruby/ruby <project_root>/ruby/rubybuild
```

## Build and Run benchmark
In the case of [redmine](https://github.com/redmine/redmine).

1. Build application docker image
```
docker-compose -f docker-compose.redmine.yml build
```

2. Build your ruby in applocation container
```
docker-compose -f docker-compose.redmine.yml run redmine /tmp/install-ruby.sh
```
then your ruby in `<project_root>/ruby/rubybuild/ruby/` is built and became executable in app container.

3. Run benchmark
```
sudo ruby run.rb -a redmine -m throughput
```

## Dependencies

- Docker
- Docker Compose
