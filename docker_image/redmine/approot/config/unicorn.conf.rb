rails_root = File.expand_path('../../', __FILE__)

rails_env = ENV['RAILS_ENV'] || 'production'

worker_processes (ENV["UNICORN_WORKERS"] || 3).to_i

working_directory rails_root

timeout 30

listen (ENV["UNICORN_PORT"] || 3000).to_i

pid File.expand_path('../../tmp/pids/unicorn.pid', __FILE__)

preload_app true

before_fork do |server, worker|
  defined?(ActiveRecord::Base) and
      ActiveRecord::Base.connection.disconnect!

  old_pid = "#{server.config[:pid]}.oldbin"
  if old_pid != server.pid
    begin
      sig = (worker.nr + 1) >= server.worker_processes ? :QUIT : :TTOU
      Process.kill(sig, File.read(old_pid).to_i)
    rescue Errno::ENOENT, Errno::ESRCH
    end
  end
end

after_fork do |server, worker|
  defined?(ActiveRecord::Base) and ActiveRecord::Base.establish_connection
end
