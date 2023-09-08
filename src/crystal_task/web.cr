require "kemal"
require "./web/*"

module CrystalTask
  class Web
    public_folder "#{__DIR__}/web"

    macro render_helper(file)
      render "#{__DIR__}/web/html/#{{{file}}}.ecr", "#{__DIR__}/web/html/layout.ecr"
    end

    get "/" do |x|
      keys, all_keys = metric_keys

      # TODO: Move all this into a pipeline
      counts = CrystalTask.metrics.counts(all_keys)
      processed_data = all_time_dashboard_stats(keys, counts)
      queued = CrystalTask.storage.queued(CrystalTask::QUEUED_QUEUE)
      retries = CrystalTask.storage.retries(CrystalTask::RETRIES_QUEUE)
      dead = CrystalTask.storage.dead(CrystalTask::DEAD_LETTER_QUEUE)
      waiting = CrystalTask.storage.waiting(processing_queues)
      scheduled = CrystalTask.storage.scheduled(CrystalTask::SCHEDULED_QUEUE)

      render_helper "index"
    end

    def self.run!
      # print the banner and do some initalization
      CrystalTask::Server.boot("web")
      # Run kemal
      Kemal.run(CrystalTask::Configuration.instance.web_port)
    end

    private def self.all_time_dashboard_stats(keys : Array(String), counts)
      processed = "processed"
      failed = "failed"
      {
        labels:   keys.map { |x| x.split(":").last if x.includes?(processed) }.compact,
        datasets: [
          {
            data:            keys.map { |x| counts[x].to_i if x.includes?(processed) }.compact,
            label:           processed.capitalize,
            borderColor:     "#00ff0040",
            backgroundColor: "#00ff00",
          },
          {
            data:            keys.map { |x| counts[x].to_i if x.includes?(failed) }.compact,
            label:           failed.capitalize,
            borderColor:     "#ff000040",
            backgroundColor: "#ff0000",
          },
        ],
      }
    end

    private def self.metric_keys
      now = Time.utc.to_s("%Y-%m-%d")
      keys = ["#{CrystalTask::PROCESSED_COUNT}:#{now}",
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
