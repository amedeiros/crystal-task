module CrystalTask
  module Middleware
    class LoggerMiddleware < Entry
      def call(job : CrystalTask::Job, &block : -> Bool) : Bool
        elapsed_time = Time.measure { yield }
        logger.info { "JOB #{job.jid} took #{elapsed_time} long to run" }

        true
      end
    end
  end
end
