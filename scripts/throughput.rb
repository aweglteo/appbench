require "socket"
require "csv"
require "yaml"
require "fileutils"

module AppBench
  class Throughput
    def initialize(tests, port, iterations = 30, worker_num = 3)
      @tests = tests
      @port = port
      @iterations = iterations
      @unicorn_workers = worker_num
    end

    def start
      puts "Starting benchmark..."

      begin

        while !port_available?
          @port += 1
        end

        ENV['UNICORN_PORT'] = @port.to_s
        ENV['UNICORN_WORKERS'] = @unicorn_workers.to_s
        FileUtils.mkdir_p(File.join('tmp', 'pids'))
        pid = spawn("bundle exec unicorn -c config/unicorn.conf.rb")
        
        while port_available?
          sleep 1
        end

        # asset precompilation is a dog, wget to force it
        system("curl -s -o /dev/null http://localhost:#{@port}/", out: $stdout, err: :out)

        results = {}

        @tests.each do |name, url|
          results[name] = bench(url, name)
        end

        mem = get_mem(pid)

        results = results.merge(
          "rss_kb" => "#{mem["rss_kb"]} KB",
          "pp_pss_kb" => "#{mem["pss_kb"]} KB"
        )

        child_pids = `ps u --ppid #{pid} | grep unicorn | awk '{ print $2; }' | grep -v PID`.split("\n")

        child_pids.each do |child|
          mem = get_mem(child)
          results["rss_worker#{child}"] = "#{mem["rss_kb"]} KB"
          results["pss_worker#{child}"] = "#{mem["pss_kb"]} KB"
        end
        
        return results

      ensure
        Process.kill "KILL", pid
      end
    end

    def port_available?
      server = TCPServer.open("0.0.0.0", @port)
      server.close
      true
    rescue Errno::EADDRINUSE
      false
    end

    # return 50, 75, 90, 99% percentile average time
    def bench(path, name)
      puts "Running apache bench warmup"
    
      `ab -n 20 -l "http://localhost:#{@port}#{path}"`
    
      puts "Benchmarking #{name} @ #{path}"
      `ab -n #{@iterations} -l -e result/ab.csv "http://localhost:#{@port}#{path}"`
    
      percentiles = Hash[*[50, 75, 90, 99].zip([]).flatten]
      CSV.foreach("result/ab.csv") do |percent, time|
        percentiles[percent.to_i] = "#{time.to_i} msec" if percentiles.key? percent.to_i
      end
    
      percentiles
    end

    def get_mem(pid)
      YAML.load `ruby appbench/scripts/memstats.rb #{pid} --yaml`
    end
  end
end
