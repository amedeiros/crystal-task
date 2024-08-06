require "./base"

module CrystalTask
  module Metrics
    class Memory < CrystalTask::Metrics::Base
      property m_metrics : Hash(String, Int64)

      def initialize
        @m_metrics = Hash(String, Int64).new
      end

      def incr(metrics : Array(String))
        metrics.each do |metric|
          self.m_metrics[metric] ||= 0
          self.m_metrics[metric] += 1
        end
      end

      def decr(metric : String)
        self.m_metrics[metric] ||= 0
        self.m_metrics[metric] -= 1 if m_metrics[metric] > 0
      end

      def get_count(metric : String) : Int64
        m_metrics[metric].to_i
      end

      def counts(metrics : Array(String)) : Hash(String, Int64)
        m_counts = Hash(String, Int64).new
        metrics.each do |metric|
          m_counts[metric] = m_metrics[metric].to_i
        end

        m_counts
      end
    end
  end
end
