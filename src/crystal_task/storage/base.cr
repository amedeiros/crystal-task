module CrystalTask
  module Storage
    # Abstract class that all storage
    # adapters must implement
    abstract class Base
      # Push/Pop operations for job processing
      abstract def pop(queues : Array(String)) : CrystalTask::Job?
      abstract def push(job : CrystalTask::Job, queue_name : String)
      abstract def bulk_push(jobs : Array(CrystalTask::Job))
      abstract def waiting(queues : Array(String)) : Array(CrystalTask::Job)

      # Push/Pop to your retry queue
      abstract def pop_retries(queue_name : String) : Array(CrystalTask::Job)?
      abstract def push_retries(job : CrystalTask::Job, queue_name : String)
      abstract def retries(queue_name : String) : Array(CrystalTask::Job)

      # Push to your dead letters queue
      abstract def push_dead(job : CrystalTask::Job, queue_name : String)
      abstract def dead(queue_name : String) : Array(CrystalTask::Job)

      # Push/Pop operation for when a job is running
      abstract def push_queued(job : CrystalTask::Job, queue_name : String)
      abstract def pop_queued(job : CrystalTask::Job, queue_name : String) : Int64
      # Return all the queued jobs
      abstract def queued(queue_name : String) : Array(CrystalTask::Job)

      # Write/Read operations for queues
      abstract def write_queue(queue_name : String, key : String)
      abstract def write_queues(queues : Array(String), key : String)
      abstract def read_queues(key : String) : Array(String)

      abstract def push_scheduled(job : CrystalTask::Job, queue_name : String, score : Int64)
      abstract def pop_scheduled(queue_name : String) : Array(CrystalTask::Job)
      abstract def bulk_push_scheduled(jobs : Array(CrystalTask::Job), queue_name : String)
      abstract def scheduled(queue_name : String) : Array(CrystalTask::Job)

      # Handle any clean up operations such as removing old stats
      abstract def cleanup

      def logger : Logger
        CrystalTask.logger
      end
    end
  end
end
