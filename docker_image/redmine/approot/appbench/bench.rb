
require_relative "./scripts/throughput"

begin
  require 'facter'
  raise LoadError if Gem::Version.new(Facter.version) < Gem::Version.new("4.0")
rescue LoadError
  system("gem install facter", out: $stdout, err: :out)
  puts "please rerun script"
  exit
end

default_port = 3000
iterations = 100

tests = [
  ["home", "/", {}]
]

th = AppBench::Throughput.new(tests, default_port, iterations)
results = th.start

facts = Facter.to_hash

facts.delete_if { |k, v|
  !["operatingsystem", "architecture", "kernelversion",
  "memorysize", "physicalprocessorcount", "processor0",
  "virtual"].include?(k)
}


results = results.merge(facts)
puts results.to_yaml

File.open("result/result.txt", "wb") do |f|
  f.write(results)
end

