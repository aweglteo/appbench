# Appbench
Easy measure rails benchmark in your developing ruby

## How to use

```
git clone https://github.com/aweglteo/appbench
```

then, put your ruby in `<project_root>/ruby/rubybuild/ruby/`. for example,   
```
git clone https://github.com/ruby/ruby appbench/ruby/rubybuild
```

### Build and Run benchmark
In the case of [redmine](https://github.com/redmine/redmine).

1. Build redmine docker image
```
docker-compose -f docker-compose.redmine.yml build
```

2. Build your ruby in application container
```
docker-compose -f docker-compose.redmine.yml run redmine /tmp/install-ruby.sh
```
then your ruby in `<project_root>/ruby/rubybuild/ruby/` is built and became executable in app container.

3. Run benchmark
```
docker-compose -f docker-compose.redmine.yml up
```

## Dependencies

- Docker
- Docker Compose
