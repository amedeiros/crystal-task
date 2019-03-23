#!/usr/bin/env crystal

require "./example_workers"

CrystalTask::Configuration.configure do |c|
  c.storage = CrystalTask::Storage::Redis.new(ENV.fetch("REDIS_HOST", "127.0.0.1"), 10)
end

HelloWorker.perform_async!(some_arg: "Hello, world!", another_arg: 1)
ErrorWorker.perform_async!
LongRunningWorker.perform_async!

CrystalTask::Server.run!
