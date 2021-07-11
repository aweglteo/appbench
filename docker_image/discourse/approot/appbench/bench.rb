
require_relative "./scripts/throughput"

begin
  require 'facter'
  raise LoadError if Gem::Version.new(Facter.version) < Gem::Version.new("4.0")
rescue LoadError
  system("gem install facter", out: $stdout, err: :out)
  puts "please rerun script"
  exit
end

default_port = 60079
iterations = 30

puts "Getting api key"
api_key = `bundle exec rake api_key:create_master[bench]`.split("\n")[-1]
headers = { 'Api-Key' => api_key, 'Api-Username' => "admin1" }

tests = [
  ["categories", "/categories"],
  ["home", "/"]
]

tests.concat(tests.map { |k, url| ["#{k}_admin", "#{url}", headers] })

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
