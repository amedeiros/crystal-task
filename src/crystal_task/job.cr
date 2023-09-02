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
    include JSON::Serializable
    # Metadata
    property created_at : Time
    property job_state : JobState
    getter queue : String
    getter jid : String
    getter klass : String
    getter args : String
    # Schedules
    getter cron : String?
    getter periodic : Int64
    # Exceptions
    property exception_msg : String?
    property exception_backtrace : String?
    property last_failed : String?
    # Retry
    property retries : Int64
    getter max_retries : Int64
    property next_retry : Int64?

    def initialize(@queue : String, @klass : String, args : NamedTuple,
                   @max_retries : Int64, @periodic : Int64, @cron : String? = nil)
      @jid = UUID.random.to_s
      @retries = Int64.new(0)
      @args = args.to_json
      @created_at = Time.utc
      @job_state = JobState::Waiting
    end
  end
end
