require "./base"

# Patch
class Redis
  class Future
    def ready?
      @ready
    end
  end
end

module CrystalTask
  module Metrics
    class Redis < CrystalTask::Metrics::Base
      getter pool : ::Redis::PooledClient

      def initialize(hostname : String = ENV.fetch("REDIS_HOST", "127.0.0.1"),
                     pool_size : Int64 = ENV.fetch("REDIS_POOL_SIZE", (System.cpu_count > 5 ? System.cpu_count : 5).to_s).to_i64)
        @pool = ::Redis::PooledClient.new(hostname, pool_size: pool_size.to_i)
      end

      def incr(metrics : Array(String))
        pool.pipelined do |pipe|
          metrics.each { |x| pipe.incr(x) }
        end
      end

      def decr(metric : String)
        pool.decr(metric)
      end

      def counts(metrics : Array(String)) : Hash(String, Int64)
        results = Hash(String, Int64).new
        futures = [] of Array(String | ::Redis::Future)

        pool.pipelined do |pipe|
          metrics.each do |metric|
            futures << [metric, pipe.get(metric)]
          end
        end

        # Wait on the futures
        while futures.size > 0
          result = futures.shift
          future = result[1].as(::Redis::Future)

          if future.ready?
            val = future.value

            if val != nil
              results[result[0].as(String)] = val.to_s.to_i64
            else
              results[result[0].as(String)] = 0
            end
          else
            futures << result
          end
        end

        results
      end

      def get_count(metric : String) : Int64
        pool.get(metric).to_i
      end
    end
  end
end
