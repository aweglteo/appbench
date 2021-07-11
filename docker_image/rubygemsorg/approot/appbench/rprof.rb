require_relative "./scripts/rprof"

default_port = 3000

tests = [
  ["home", "/", {}]
]

rprof = AppBench::RProf.new(tests, default_port)
rprof.start
