require 'optparse'
require 'yaml'
require "pathname"

# supporting settings
APP_TYPES = %i(discourse redmine rubygems)
DB_TYPES = %i(postgres)
APPSERVER_TYPES = %i(unicorn)
METRICS_TYPES = %i(throughput rprof)

@tar_app = ""
@ruby_dir = nil
@output_file = "output.txt"

opts = OptionParser.new do |o|
  o.banner = "Usage: ruby script.rb [options]"

  o.on("-a", "--rails_app APP", "Designate rails application") do |a|
    @tar_app = a
  end
  o.on("-t", "--ruby_dir [DIRPATH]", "Designate ruby source directory") do |d|
    @ruby_dir = d
  end
  o.on("-o", "--output [FILE]", "Output benchmark results to this filename") do |f|
    @output_file = f
  end
end

opts.parse!

ARGS_TYPES = %i(build up)
abort 'designate [build | up ]' unless ARGS_TYPES.include?(ARGV.first&.intern)

if @tar_app.empty?
  puts "Sorry, designate target rails application with -a option. for now supporting these applications below."
  puts "  #{APP_TYPES.map(&:to_s).join(" ")}"
  exit
end

config = open(__dir__ + '/config.yml', 'r') do |f|
  YAML.load(f)
end

# check args and config.yml 
%i(database appserver target).each do |key|
  if config[key.to_s].nil?
    puts "Error, check config.yml. all keys must be designated."
    exit
  end
end

unless DB_TYPES.include?(config["database"]&.intern)
  puts "Error, unsurpotted database type. For now only surporting postgres"
  exit
end

unless APPSERVER_TYPES.include?(config["appserver"]&.intern)
  puts "Error, unsurpotted application server type. For now only surporting puma"
  exit
end

unless APP_TYPES.include?(@tar_app.intern)
  puts "Error, unsurpotted application type. For now only surporting [#{APP_TYPES.map(&:to_s).join(" ")}]"
  exit
end

unless METRICS_TYPES.include?(config["target"].intern)
  puts "Error, unsurpotted metrics type."
  exit
end

# pass benchtool config to DockerContainer thorought .env file
`echo "APPBENCH_APPSERVER=#{config["appserver"]}" > #{Pathname(__dir__).join(".env")}`
`echo "APPBENCH_DATABASE=#{config["database"]}" >> #{Pathname(__dir__).join(".env")}`
`echo "APPBENCH_TARGET=#{config["target"]}" >> #{Pathname(__dir__).join(".env")}`

if ARGV.first == "build"
  system("docker-compose -f #{Pathname(__dir__).join("docker-compose.#{@tar_app}.yml")} build", out: $stdout, err: :out)
elsif ARGV.first == "up"
  system("docker-compose -f #{Pathname(__dir__).join("docker-compose.#{@tar_app}.yml")} up", out: $stdout, err: :out)
end
