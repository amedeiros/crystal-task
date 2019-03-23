require "../crystal_task"

class PeriodicWorker
  include CrystalTask::Worker

  retries 0
  periodic 2.minutes

  def perform(args : Hash(String, JSON::Any))
    logger.info "PeriodicWorker time: #{Time.now}"
  end
end

class HelloWorker
  include CrystalTask::Worker

  queue "another-queue"
  retries 2

  def perform(args : Hash(String, JSON::Any))
    logger.info "#{args["some_arg"]}"
    logger.info "Another: #{args["another_arg"]}"
  end
end

class LongRunningWorker
  include CrystalTask::Worker

  def perform(args : Hash(String, JSON::Any))
    sleep 60
  end
end

class CronWorker
  include CrystalTask::Worker

  cron "* * * * *"

  def perform(args : Hash(String, JSON::Any))
    logger.info("CronWorker time: #{Time.now}")
  end
end

class CronWorkerTwo
  include CrystalTask::Worker

  cron "*/2 * * * *"

  def perform(args : Hash(String, JSON::Any))
    logger.info("CronWorkerTwo time: #{Time.now}")
  end
end

class ErrorWorker
  include CrystalTask::Worker

  retries 2

  def perform(args : Hash(String, JSON::Any))
    raise "Example of an erroing worker!"
  end
end
