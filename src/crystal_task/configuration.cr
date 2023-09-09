require "./storage/base"
require "./metrics/base"
require "./metrics/redis"

module CrystalTask
  class Configuration
    property storage : CrystalTask::Storage::Base
    property metrics : CrystalTask::Metrics::Base
    property max_fibers : Int64
    property web_port : Int32

    # Defaults
    private def initialize
      @storage = CrystalTask::Storage::Redis.new
      @metrics = CrystalTask::Metrics::Redis.new
      @max_fibers = System.cpu_count
      @web_port = 3001
    end

    def self.instance : CrystalTask::Configuration
      @@instance ||= new
    end

    def self.configure(&block)
      yield instance
    end
  end
end
