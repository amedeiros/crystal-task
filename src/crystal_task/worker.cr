require "./job"

module CrystalTask
  # Include this module to have an async worker.
  module Worker
    # Override the queue with the `queue` macro
    @@queue : String?

    # Override the retries with the `retries` macro
    @@retries : Int64?

    # Periodically execute this worker
    @@periodic : Time::Span?

    # Define a cron style pattern to run this job like a cron job!
    @@cron : String?

    # Register this worker on include
    macro included 
      extend CrystalTask::Worker::ClassMethods

      if !@@periodic.nil?
        CrystalTask.register_periodic_worker({{@type}}.new)
      elsif !@@cron.nil?
        CrystalTask.register_cron_worker({{@type}}.new)
      else
        CrystalTask.register_worker({{@type}}.new)
      end

      CrystalTask.register_processing_queue(self.queue)
    end

    # Implement your own perform method.
    abstract def perform(args : Hash(String, JSON::Any))

    def logger
      CrystalTask.logger
    end

    # Modify the queue for this worker
    macro queue(name)
      @@queue = {{name}}
    end

    # Run this job periodically
    macro periodic(t)
      @@periodic = {{t}}.as(Time::Span)
    end

    # Modify the retry count
    macro retries(retries)
      @@retries = Int64.new({{retries}})
    end

    macro cron(cron)
      @@cron = {{cron}}
    end

    module ClassMethods
      # Queue this job
      def perform_async!(**args)
        job = new_job(**args)
        CrystalTask.storage.push(job, job.queue)
      end

      def new_job(**args)
        Job.new(queue, name, args, retries, periodic.to_i, cron)
      end

      def queue : String
        @@queue || CrystalTask::DEFAULT_QUEUE
      end

      def retries : Int64
        @@retries || Int64.new(1)
      end

      def periodic : Time::Span?
        @@periodic || 0.minutes
      end

      def cron : String?
        @@cron
      end
    end
  end
end
