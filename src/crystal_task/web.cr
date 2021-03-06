require "kemal"
require "../crystal_task"
require "./web/*"

module CrystalTask
  class Web
    public_folder "#{__DIR__}/web"

    macro render_helper(file)
      render "src/crystal_task/web/html/#{{{file}}}.ecr", "src/crystal_task/web/html/layout.ecr"
    end

    get "/" do |x|
      keys, all_keys  = metric_keys

      # TODO: Move all this into a pipeline
      counts          = CrystalTask.metrics.counts(all_keys)
      processed_data  = stats("processed", keys, counts)
      failed_data     = stats("failed", keys, counts)
      queued          = CrystalTask.storage.queued(CrystalTask::QUEUED_QUEUE)
      retries         = CrystalTask.storage.retries(CrystalTask::RETRIES_QUEUE)
      dead            = CrystalTask.storage.dead(CrystalTask::DEAD_LETTER_QUEUE)
      waiting         = CrystalTask.storage.waiting(processing_queues)
      scheduled       = CrystalTask.storage.scheduled(CrystalTask::SCHEDULED_QUEUE)

      render_helper "index"
    end

    def self.run!
      # print the banner and do some initalization
      CrystalTask::Server.boot("web")
      # Run kemal
      Kemal.run(CrystalTask::Configuration.instance.web_port)
    end

    private def self.stats(metric : String, keys, counts)
      {
        labels: keys.map { |x| x.split(":").last if x.includes?(metric) }.compact,
        datasets: [ { data: keys.map { |x| counts[x].to_i if x.includes?(metric) }.compact,
                      label: metric.capitalize } ],
      }
    end

    private def self.metric_keys
      now   = Time.now.to_s("%Y-%m-%d")
      keys  = ["#{CrystalTask::PROCESSED_COUNT}:#{now}",
               "#{CrystalTask::FAILED_COUNT}:#{now}"] of String

      7.times do |x|
        ago = ":" + (x + 1).days.ago.to_s("%Y-%m-%d")
        keys << CrystalTask::PROCESSED_COUNT + ago
        keys << CrystalTask::FAILED_COUNT + ago
      end

      [keys.sort, (keys + CrystalTask::METRICS_KEYS).sort]
    end

    private def self.processing_queues
      CrystalTask.storage.read_queues(CrystalTask::QUEUES_KEY).select! { |x| !CrystalTask.lifecycle_queues.includes?(x) }
    end
  end
end
