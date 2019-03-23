require "cron_parser"
require "./crystal_task/logger"
require "./crystal_task/job"
require "./crystal_task/worker"
require "./crystal_task/configuration"
require "./crystal_task/storage/redis"
require "./crystal_task/server"

module CrystalTask
  VERSION = "0.1.0"

  # Default Namespace
  REDIS_NAMESPACE = "crystal_task:"
  QUEUES_KEY      = REDIS_NAMESPACE + "queues"

  # Default queues
  DEAD_LETTER_QUEUE = REDIS_NAMESPACE + "dead_letter"
  RETRIES_QUEUE     = REDIS_NAMESPACE + "retries"
  QUEUED_QUEUE      = REDIS_NAMESPACE + "queued"
  DEFAULT_QUEUE     = REDIS_NAMESPACE + "default"
  SCHEDULED_QUEUE   = REDIS_NAMESPACE + "scheduled"

  # Default metric names
  STATS_NAMESPACE = REDIS_NAMESPACE + "stats:"
  PROCESSED_COUNT = STATS_NAMESPACE + "processed"
  FAILED_COUNT    = STATS_NAMESPACE + "failed"
  METRICS_KEYS    = [PROCESSED_COUNT, FAILED_COUNT] of String

  # Store instances of the workers
  @@workers = Hash(String, CrystalTask::Worker).new

  # Store the queues
  @@processing_queues : Array(String) = Array(String).new
  @@lifecycle_queues  : Array(String) = [RETRIES_QUEUE, DEAD_LETTER_QUEUE, QUEUED_QUEUE]

  # Default logger
  @@logger = Logger.new(STDOUT, level: Logger::DEBUG)

  def self.logger=(logger : Logger)
    @@logger = logger
  end

  def self.logger : Logger
    @@logger
  end

  def self.register_worker(worker : CrystalTask::Worker)
    @@workers[worker.class.name] ||= worker
  end

  def self.register_periodic_worker(worker : CrystalTask::Worker)
    # Standard registration applies
    register_worker(worker)

    # Queue periodic job for right now to run right away
    # The server will pop the job and schedule it to its next interval.
    CrystalTask.storage.push_scheduled(worker.class.new_job, SCHEDULED_QUEUE, unix_epoch)
  end

  def self.register_cron_worker(worker : CrystalTask::Worker)
    # Standard registration applies
    register_worker(worker)

    # Cron scheduling is more percise than periodic.
    # Don't schedule now schedule for next interval.
    cron_parser = CronParser.new(worker.class.cron.as(String))
    time        = cron_parser.next(Time.now)
    score       = (time - Time::UNIX_EPOCH).to_i

    CrystalTask.storage.push_scheduled(worker.class.new_job, SCHEDULED_QUEUE, score)
  end

  def self.worker(worker : String) : CrystalTask::Worker
    raise "Missing worker #{worker}" if !@@workers.has_key?(worker)
    @@workers[worker].dup
  end

  def self.max_fibers : Int64
    CrystalTask::Configuration.instance.max_fibers
  end

  def self.register_processing_queue(queue : String)
    if !processing_queue?(queue)
      @@processing_queues.push(queue) 
      storage.write_queue(queue, QUEUES_KEY)
    end
  end

  def self.processing_queue?(queue : String) : Bool
    @@processing_queues.includes?(queue)
  end

  def self.processing_queues : Array(String)
    @@processing_queues
  end

  def self.lifecycle_queues : Array(String)
    @@lifecycle_queues
  end

  def self.queues : Array(String)
    @@processing_queues + @@lifecycle_queues
  end

  def self.storage : CrystalTask::Storage::Base
    CrystalTask::Configuration.instance.storage
  end

  def self.metrics : CrystalTask::Metrics::Base
    CrystalTask::Configuration.instance.metrics
  end

  def self.spawn_safe_fiber(&block)
    spawn do
      loop do
        begin
          block.call
        rescue exc : Exception
          CrystalTask.logger.error("Caught unhandled exception...")
          CrystalTask.logger.error(exc)
        end
      end
    end
  end

  def self.unix_epoch : Int64
    (Time.now - Time::UNIX_EPOCH).to_i
  end
end
