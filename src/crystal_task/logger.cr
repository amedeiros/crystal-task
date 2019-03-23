
require "logger"

module CrystalTask
  class Logger < ::Logger

    {% for meth in %w(info debug warn error) %}
      def {{meth.id}}_as_json(msg : NamedTuple)
        {{meth.id}}(msg.to_json)
      end
    {% end %}
  end
end