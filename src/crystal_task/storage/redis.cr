require "system"
require "redis"
require "redis/pooled_client"

# TODO: Reliable queue https://redis.io/commands/rpoplpush
module CrystalTask
  module Storage
    class Redis < CrystalTask::Storage::Base
      getter pool : ::Redis::PooledClient

      def initialize(hostname : String = ENV.fetch("REDIS_HOST", "127.0.0.1"),
                     pool_size : Int64 = ENV.fetch("REDIS_POOL_SIZE", (System.cpu_count > 5 ? System.cpu_count : 5).to_s).to_i64)
        @pool = ::Redis::PooledClient.new(hostname, pool_size: pool_size.to_i)
      end

      def waiting(queues : Array(String)) : Array(CrystalTask::Job)
        pool.pipelined do |pipeline|
          queues.each do |queue|
            pipeline.lrange(queue, 0, -1)
          end
        end.map { |x| x.as(Array(::Redis::RedisValue)).map { |y| Job.from_json(y.as(String)) } }.flatten
      end

      def push(job : CrystalTask::Job, queue_name : String)
        pool.lpush(queue_name, job.to_json)
      end

      def bulk_push(jobs : Array(CrystalTask::Job))
        pool.pipelined do |pipeline|
          jobs.each do |job|
            pipeline.lpush(job.queue, job.to_json)
          end
        end
      end

      # Blocking
      def pop(queues : Array(String)) : CrystalTask::Job?
        val = pool.brpop(queues, 2)
        collection = val.as(Array(::Redis::RedisValue))
        return nil if collection.empty?

        json = collection[1].as(String)

        CrystalTask::Job.from_json(json)
      end

      def pop_retries(queue_name : String) : Array(CrystalTask::Job)?
        zremrangebyscore(queue_name)
      end

      def push_retries(job : CrystalTask::Job, queue_name : String)
        logger.info_as_json({
          job:           job.jid,
          queue:         job.queue,
          msg:           "Pushing to retries queue",
          exception_msg: job.exception_msg,
          next_retry:    Time.unix(job.next_retry.as(Int)),
          retry_count:   job.retries,
          failed_at:     job.last_failed,
          klass:         job.klass,
        })

        job.job_state = CrystalTask::JobState::Retry
        pool.zadd(queue_name, job.next_retry, job.to_json)
      end

      def retries(queue_name : String) : Array(CrystalTask::Job)
        pool.zrange(queue_name, 0, -1).as(Array(::Redis::RedisValue)).map { |x| CrystalTask::Job.from_json(x.as(String)) }
      end

      def push_dead(job : CrystalTask::Job, queue_name : String)
        logger.info_as_json({
          job:           job.jid,
          queue:         job.queue,
          exception_msg: job.exception_msg,
          msg:           "Pushing to dead queue",
          retry_count:   job.retries,
          failed_at:     job.last_failed,
          klass:         job.klass,
        })

        job.job_state = CrystalTask::JobState::Dead

        pool.pipelined do |pipeline|
          pipeline.zadd(queue_name, CrystalTask.unix_epoch, job.to_json)
          pipeline.zremrangebyscore(queue_name, "-inf", (1.month.ago - Time::UNIX_EPOCH).to_i)
          pipeline.zremrangebyrank(queue_name, 0, -10_000)
        end
      end

      # Same type of data type as the retries
      def dead(queue_name : String) : Array(CrystalTask::Job)
        retries(queue_name)
      end

      def push_queued(job : CrystalTask::Job, queue_name : String)
        job.job_state = CrystalTask::JobState::Queued
        pool.sadd(queue_name, job.to_json)
      end

      def pop_queued(job : CrystalTask::Job, queue_name : String) : Int64
        pool.srem(queue_name, job.to_json)
      end

      def queued(queue_name : String) : Array(CrystalTask::Job)
        pool.smembers(queue_name).as(Array(::Redis::RedisValue)).map { |x| Job.from_json(x.as(String)) }
      end

      def write_queue(queue_name : String, key : String)
        pool.sadd(key, queue_name)
      end

      def write_queues(queues : Array(String), key : String)
        pool.pipelined do |pipeline|
          queues.each do |queue|
            pipeline.sadd(key, queue)
          end
        end
      end

      def read_queues(key : String) : Array(String)
        pool.smembers(key).as(Array(::Redis::RedisValue)).map { |x| x.as(String) }
      end

      def push_scheduled(job : CrystalTask::Job, queue_name : String, score : Int64)
        return if scheduled(queue_name).any? { |x| x.klass == job.klass }
        pool.zadd(queue_name, score, job.to_json)
      end

      def bulk_push_scheduled(jobs : Array(CrystalTask::Job), queue_name : String)
        # Figure out the score here because we can have mixed jobs of cron or periodic
        pool.pipelined do |pipeline|
          jobs.each do |job|
            if job.cron.nil? # periodic
              time = (CrystalTask.unix_epoch + CrystalTask.worker(job.klass).class.periodic.to_i).to_i64
              pipeline.zadd(queue_name, time, job.to_json)
            else # cron
              cron_parser = CronParser.new(CrystalTask.worker(job.klass).class.cron.as(String))
              time = cron_parser.next(Time.utc)
              score = (time - Time::UNIX_EPOCH).to_i

              pipeline.zadd(queue_name, score, job.to_json)
            end
          end
        end
      end

      def scheduled(queue_name : String) : Array(CrystalTask::Job)
        pool.zrange(queue_name, 0, -1).as(Array(::Redis::RedisValue)).map { |x| CrystalTask::Job.from_json(x.as(String)) }
      end

      def pop_scheduled(queue_name : String) : Array(CrystalTask::Job)
        zremrangebyscore(queue_name)
      end

      def cleanup
        # Stats day keys
        keys_processed = pool.keys("*:processed:#{Time.utc.year}*").as(Array(::Redis::RedisValue)).map { |x| x.as(String) }.sort
        keys_failed = pool.keys("*:failed:#{Time.utc.year}*").as(Array(::Redis::RedisValue)).map { |x| x.as(String) }.sort
        # Clean up stats greater than 30 days
        keys = [] of String
        keys += keys_processed[0..(keys_processed.size - 30)]
        keys += keys_failed[0..(keys_failed.size - 30)]

        pool.pipelined do |pipe|
          keys.each { |x| pipe.del(x) }
        end
      end

      private def zremrangebyscore(queue_name : String) : Array(CrystalTask::Job)?
        begin
          now = CrystalTask.unix_epoch
          jobs = pool.zrangebyscore(queue_name, "-inf", now)
          collection = jobs.as(Array(::Redis::RedisValue))

          return Array(CrystalTask::Job).new if collection.empty?
          pool.zremrangebyscore(queue_name, "-inf", now)

          collection.map { |x| CrystalTask::Job.from_json(x.as(String)) }
        rescue exc : ::Redis::Error
          logger.warn(exception: exc) { exc.message }
          return Array(CrystalTask::Job).new
        end
      end
    end
  end
end
