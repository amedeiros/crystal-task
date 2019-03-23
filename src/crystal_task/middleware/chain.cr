module CrystalTask
  module Middleware
    class NotFoundException < Exception; end

    class Chain(T)
      getter middleware : Array(T)

      def initialize
        @middleware = Array(T).new
      end

      def exec(job : CrystalTask::Job, &block : -> Bool)
        next_link(middleware.dup, job, &block)
      end

      def add(m : T)
        delete(m)
        middleware.push(m)
      end

      def delete(m : T)
        middleware.reject! { |x| x.class == m.class }
      end

      def insert_before(old_klass : Class, new_klass : T)
        id = middleware.index { |x| x.class == old_klass }

        if id
          middleware.insert(id, new_klass)
        else
          raise NotFoundException.new("Missing middleware #{old_klass}")
        end
      end

      def insert_after(old_klass : Class, new_klass : T)
        id = middleware.index { |x| x.class == old_klass }

        if id
          id += 1
          middleware.insert(id, new_klass)
        else
          raise NotFoundException.new("Missing middleware #{old_klass}")
        end
      end

      private def next_link(chain : Array(T), job : CrystalTask::Job, &block)
        if chain.empty?
          block.call
        else
          chain.shift.call(job) do
            next_link(chain, job, &block)
          end
        end
      end
    end
  end
end
