require "./middleware/base"
require "./middleware/chain"
require "./middleware/retry_middleware"
require "./middleware/logger_middleware"

module CrystalTask
  class Server
    # Buffered work channel the size of our max_fibers
    @@work = Channel(CrystalTask::Job).new(CrystalTask.max_fibers.to_i)

    # Unbound completed channel for recording stats
    @@completed = Channel(CrystalTask::Job).new

    # Unbound queued channel for pushing running jobs to the queued queue
    @@queued = Channel(CrystalTask::Job).new

    # Default middleware
    @@middleware : CrystalTask::Middleware::Chain(CrystalTask::Middleware::Entry) = CrystalTask::Middleware::Chain(CrystalTask::Middleware::Entry).new.tap do |m|
      m.add(CrystalTask::Middleware::LoggerMiddleware.new)
      m.add(CrystalTask::Middleware::RetryMiddleware.new)
    end

    # Return the work channel
    def self.work : Channel(CrystalTask::Job)
      @@work
    end
    
    # Return the queued channel
    def self.queued : Channel(CrystalTask::Job)
      @@queued
    end

    # Return the completed channel
    def self.completed : Channel(CrystalTask::Job)
      @@completed
    end

    # Return the middleware
    def self.middleware : CrystalTask::Middleware::Chain(CrystalTask::Middleware::Entry)
      @@middleware
    end

    def self.run!
      print_banner
      boot("worker")

      # Process the queues with the max threads configured
      CrystalTask.max_fibers.times do
        CrystalTask.spawn_safe_fiber do
          job = CrystalTask.storage.pop(CrystalTask.processing_queues.shuffle.uniq)
          work.send(job) if job
        end
      end

      # Manage the retries queue separately
      CrystalTask.spawn_safe_fiber do
        jobs = CrystalTask.storage.pop_retries(CrystalTask::RETRIES_QUEUE)
        CrystalTask.storage.bulk_push(jobs) if !jobs.empty?
      end

      # Manage the scheduled queue separately
      CrystalTask.spawn_safe_fiber do
        jobs = CrystalTask.storage.pop_scheduled(CrystalTask::SCHEDULED_QUEUE)
        if !jobs.empty?
          CrystalTask.storage.bulk_push(jobs)
          CrystalTask.storage.bulk_push_scheduled(jobs, CrystalTask::SCHEDULED_QUEUE)
        end
      end

      # Record the processed count metric.
      # Retry middleware will remove the job from the queued and push it to retries || dead.
      # If the job is still in queued queue after processing it was succesful.
      CrystalTask.spawn_safe_fiber do
        job = completed.receive

        if job
          if CrystalTask.storage.pop_queued(job, CrystalTask::QUEUED_QUEUE) == 1
            CrystalTask.metrics.incr(
              [CrystalTask::PROCESSED_COUNT,
              CrystalTask::PROCESSED_COUNT + ":" +  Time.now.to_s("%Y-%m-%d")])
          end
        end
      end

      # Queue running jobs here to
      # not block the processing fibers.
      CrystalTask.spawn_safe_fiber do
        job = queued.receive
        CrystalTask.storage.push_queued(job, CrystalTask::QUEUED_QUEUE) if job
      end

      # Manage the job by passing it through the middleware
      loop do
        job = work.receive

        if job
          spawn do
            begin
              # Push the job onto the queued queue
              job.job_state = CrystalTask::JobState::Queued
              queued.send(job)

              worker = CrystalTask.worker(job.klass)
              args   = JSON.parse(job.args).raw.as(Hash(String, JSON::Any))

              # Import to pass a copy of the job to the middleware.
              # This is because the middleware can alter the job.
              @@middleware.exec(job.dup) do
                worker.perform(args)
                true
              end

              completed.send(job)
            rescue exc : Exception
              CrystalTask.logger.error(exc)
            end
          end
        end
      end
    end

    def self.print_banner
      puts "\e[#{31}m"
      puts banner
      puts "\e[0m"
    end

    def self.boot(kind)
      CrystalTask.logger.info("Crystal Task VERSION: #{CrystalTask::VERSION}")

      CrystalTask.logger.info("Writing queues #{CrystalTask.queues.join(", ")}")
      CrystalTask.storage.write_queues(CrystalTask.queues, CrystalTask::QUEUES_KEY)

      CrystalTask.logger.info("Housekeeping...")
      CrystalTask.storage.cleanup

      CrystalTask.logger.info("Starting #{kind} server....")
    end

    def self.banner
      %q{
       _______  _______           _______ _________ _______  _         _________ _______  _______  _       
      (  ____ \(  ____ )|\     /|(  ____ \\__   __/(  ___  )( \        \__   __/(  ___  )(  ____ \| \    /\
      | (    \/| (    )|( \   / )| (    \/   ) (   | (   ) || (           ) (   | (   ) || (    \/|  \  / /
      | |      | (____)| \ (_) / | (_____    | |   | (___) || |           | |   | (___) || (_____ |  (_/ / 
      | |      |     __)  \   /  (_____  )   | |   |  ___  || |           | |   |  ___  |(_____  )|   _ (  
      | |      | (\ (      ) (         ) |   | |   | (   ) || |           | |   | (   ) |      ) ||  ( \ \ 
      | (____/\| ) \ \__   | |   /\____) |   | |   | )   ( || (____/\     | |   | )   ( |/\____) ||  /  \ \
      (_______/|/   \__/   \_/   \_______)   )_(   |/     \|(_______/     )_(   |/     \|\_______)|_/    \/
}
    end
  end
end