## Appbench

rails benchmark tool

### build app enviroment

```
ruby run.rb build -a [ discourse | rubygems | redmine ]
```

### exec bench

build app enviroment before executing benchmark 

```
ruby run.rb up -a [ discourse | rubygems | redmine ] -m [ throughput | rprof ]
```

## Dependencies

- Docker
- Docker Compose
