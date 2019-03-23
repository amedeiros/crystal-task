require "json"
require "uuid/json"

module CrystalTask
  # A Job represents a unit of work in the queue
  enum JobState
    Waiting # Default
    Queued  # Running
    Paused  # Paused
    Retry   # Waiting to retry
    Dead    # Exhausted all retries
  end

  class Job
    # Information to store with the job
    JSON.mapping({
      queue:               String,
      jid:                 String,
      klass:               String,
      exception_msg:       String?,
      exception_backtrace: String?,
      last_failed:         String?,
      cron:                String?,
      job_state:           JobState,
      retries:             Int64,
      max_retries:         Int64,
      periodic:            Int64,
      next_retry:          Int64?,
      args:       { type: String, converter: String::RawConverter },
      created_at: { type: Time, converter: Time::EpochConverter },
    })

    def initialize(queue, klass : String, args : NamedTuple, max_retries : Int64, periodic : Int64, cron : String?)
      @queue       = queue
      @jid         = UUID.random.to_s
      @klass       = klass
      @retries     = 0
      @max_retries = max_retries
      @args        = args.to_json
      @created_at  = Time.now
      @job_state   = JobState::Waiting
      @periodic    = periodic
      @cron        = cron
    end
  end
end

