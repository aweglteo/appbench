require "socket"
require "csv"
require "yaml"
require "fileutils"

module AppBench
  class RProf
    def initialize(paths, port)
      @paths = paths
      @port = port
    end

    def start
      puts "Starting profiling ..."

      begin

        while !port_available?
          @port += 1
        end

        FileUtils.mkdir_p(File.join('tmp', 'pids'))
        FileUtils.mkdir_p('stackprof')
        pid = spawn("ENABLE_STACKPROF=1 bundle exec puma -w 3 -p #{@port} -e production")
        
        while port_available?
          sleep 1
        end

        system("curl -s -o /dev/null http://localhost:#{@port}/", out: $stdout, err: :out)

        @paths.each do |name, url|
          access(url, name)
        end

        system("stackprof stackprof/stackprof-cpu-*.dump --text --limit 50")
    
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

    def access(path, name)
      puts "Running apache bench warmup"
    
      `ab -n 10 -l "http://localhost:#{@port}#{path}"`
    
      puts "Benchmarking #{name} @ #{path}"
      `ab -n 50 -l "http://localhost:#{@port}#{path}"`
    end
  end
end

