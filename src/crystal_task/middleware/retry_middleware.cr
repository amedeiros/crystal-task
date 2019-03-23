module CrystalTask
  module Middleware
    class RetryMiddleware < Entry
      # Caputre any exceptions from the job and either push
      # to the retries queue or the dead queue.
      def call(job : CrystalTask::Job, &block : -> Bool) : Bool
        begin
          yield
        rescue exc : Exception
          # Remove from the queued queue before modifying the job
          CrystalTask.storage.pop_queued(job, CrystalTask::QUEUED_QUEUE)

          job.retries            += 1
          job.exception_msg       = exc.message
          job.exception_backtrace = exc.backtrace.join("\n")
          job.last_failed         = Time.now.to_s
          job.next_retry          = backoff(job.retries)

          if job.retries >= job.max_retries
            # Move to dead letters queue
            job.job_state = CrystalTask::JobState::Dead
            CrystalTask.storage.push_dead(job, CrystalTask::DEAD_LETTER_QUEUE)
          else
            # Move to retries queue
            job.job_state = CrystalTask::JobState::Retry
            CrystalTask.storage.push_retries(job, CrystalTask::RETRIES_QUEUE)
          end

          # Record the fail metric
          CrystalTask.metrics.incr(
            [CrystalTask::FAILED_COUNT,
             CrystalTask::FAILED_COUNT + ":" + Time.now.to_s("%Y-%m-%d")])
        end

        true
      end

      private def unix_epoch : Int64
        (Time.now - Time::UNIX_EPOCH).to_i
      end
  
      private def backoff(retries : Int64) : Int64
        unix_epoch + (retries ** 4) + 15 + (rand(30) * (retries + 1))
      end
    end
  end
end
