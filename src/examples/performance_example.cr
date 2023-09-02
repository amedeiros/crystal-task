require "../crystal_task"
require "option_parser"
require "colorize"

fibers : Int64 = 4
pool : Int64 = 5

OptionParser.parse do |parser|
  parser.on("-t COUNT", "--fibers COUNT", "Fibers reading off queues") { |x| fibers = x.to_i64 }
  parser.on("-p COUNT", "--pool COUNT", "Redis pool") { |x| pool = x.to_i64 }
  parser.on("-h", "--help", "Show this help") do
    CrystalTask::Server.print_banner
    puts parser
    exit(0)
  end
end

class PerformanceTestWorker
  include CrystalTask::Worker

  retries 1

  def perform(args : Hash(String, JSON::Any))
    # no-op
  end
end

CrystalTask::Configuration.configure do |c|
  c.storage = CrystalTask::Storage::Redis.new(ENV.fetch("REDIS_HOST", "127.0.0.1"), pool)
  c.metrics = CrystalTask::Metrics::Redis.new(ENV.fetch("REDIS_HOST", "127.0.0.1"), pool)
  c.max_fibers = fibers
end

CrystalTask.logger.level = Log::Severity::Warn
CrystalTask.storage.pool.flushdb

total_jobs = 100_000
jobs = [] of CrystalTask::Job
total_jobs.times do
  jobs << PerformanceTestWorker.new_job
end

CrystalTask.storage.bulk_push(jobs)

spawn do
  start = Time.utc

  loop do
    qsize, retries = CrystalTask.storage.pool.pipelined do |pipe|
      pipe.llen CrystalTask::DEFAULT_QUEUE
      pipe.zcard CrystalTask::RETRIES_QUEUE
    end.map { |x| x.as(Int64) }

    total = qsize + retries
    CrystalTask.logger.warn { "Pending: #{total}" }

    if total.zero?
      stop = Time.utc
      puts "Done in #{stop - start}: #{"%.3f" % (total_jobs / (stop - start).to_f)} jobs/sec".colorize(:red)
      exit 0
    end

    sleep 1
  end
end

# crystal build src/examples/performance_example.cr --release
# ./performance_example -t 34 -p 40
CrystalTask::Server.run!
