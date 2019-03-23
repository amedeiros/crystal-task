module CrystalTask
  module Metrics
    abstract class Base
      abstract def incr(metric : Array(String))
      abstract def decr(metric : String)
      abstract def get_count(metric : String) : String?
      abstract def counts(metric : Array(String)) : Hash(String, Int64)
    end
  end
end
