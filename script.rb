# frozen_string_literal: true

require 'optparse'
require 'yaml'
require 'pry'

require 'docker/compose'

# supporting middleware
APP_TYPES = %i(discourse redmine rubygems)
DB_TYPES = %i(postgres)
APPSERVER_TYPES = %i(puma)

@tar_ruby_dir = nil
@result_file = nil

opts = OptionParser.new do |o|
  o.banner = "Usage: ruby script.rb [options]"

  o.on("-a", "--target_app APP", "Designate target rails application") do |a|
    @tar_app = a
  end
  o.on("-t", "--target_ruby_dir [DIRPATH]", "Designate ruby source directory") do |d|
    @tar_ruby_dir = d
  end
  o.on("-o", "--output [FILE]", "Output benchmark results to this file") do |f|
    @result_file = f
  end
  o.on("-i", "--iterations [ITERATIONS]", "Number of iterations to run the bench for") do |i|
    @iterations = i.to_i
  end
  o.on("-c", "--concurrency [NUM]", "Run benchmark with this number of concurrent requests (default: 1)") do |i|
    @concurrency = i.to_i
  end  
end
opts.parse!

config = open(__dir__ + '/config.yml', 'r') do |f|
  YAML.load(f)
end

# check args and config.yml 
%i(database appserver benchtool result).each do |key|
  if config[key.to_s].nil?
    puts "Error, check config.yml.  all keys must be designated."
    exit
  end
end

if DB_TYPES.include?(config["database"])
  puts "Error, unsurpotted database, For now only surporting postgres"
  exit
end

if APPSERVER_TYPES.include?(config["appserver"])
  puts "Error, unsurpotted database, For now only surporting postgres"
  exit
end

unless APP_TYPES.include?(@tar_app.intern)
  puts "Error, unsurpotted application. For now only surporting [#{APP_TYPES.map(&:to_s).join(" ")}]"
  exit
end

