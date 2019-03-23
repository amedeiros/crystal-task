
module CrystalTask
  module Middleware
    abstract class Base
      abstract def call(job : CrystalTask::Job, &block : -> Bool) : Bool

      def logger : Logger
        CrystalTask.logger
      end
    end

    abstract class Entry < Base; end
  end
end
