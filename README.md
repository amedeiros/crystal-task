# Crystal Task

Background workers for Crystal. Similar to other background systems. There is a horrible UI that is just there.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     crystal_task:
       github: amedeiros/crystal_task
   ```

2. Run `shards install`

## Usage

```crystal
require "crystal_task"
```

Creating a worker is as easy as including CystalTask::Worker and implementing the perform function.

```crystal
class ExampleWorker
  include CrystalTask::Worker
  
  retries 5              # adjust how many times this job can be retried
  queue "examples-queue" # change the queue from the default queue 'default' to your own.

  def perform(args : Hash(String, JSON::Any))
    logger.info("Hello, Crystal Task!")
    logger.info(args["x"].as(Int64) + args["y"].as(Int64))
  end
end
```

Queue work for the worker. `ExampleWorker.perform_async!(x: 1, y: 1)`

There is the concept of periodic workers that can run on interval. They are less percise than the 
cron style workers see below.

```crystal
class PeriodicWorker
  include CrystalTask::Worker

  # 10.minutes, 1.minutes, 1.month etc...
  # EX: First run 10:05:36 next run 11:05:36
  periodic 1.hour  

  def perform(args : Hash(String, JSON::Any))
    # do some work on an interval
  end
```

```crystal
class CronWorker
  include CrystalTask::Worker

  # Every minute on the minute.
  # Ex: First run 10:05:00 next run 10:06:00
  cron "* * * * *"

  def perform(args : Hash(String, JSON::Any))
    logger.info("CronWorker time: #{Time.now}")
  end
end
```

Running the worker server.

```crystal
#!/usr/bin/env crystal
require "crystal_task/server"
CrystalTask::Server.run!
```

Running the web server.

```crystal
#!/usr/bin/env crystal
require "crystal_task/web"
CrystalTask::Web.run!
```

## Configuring

TODO: This

## Development

Currently on going with the API changing with each commit.

Need help with the UI and anything anyone wants to contribute. Feel free to make pull requests!

## Contributing

1. Fork it (<https://github.com/amedeiros/crystal_task/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Andrew Medeiros](https://github.com/amedeiros) - creator and maintainer
