require "redis"

require "foobara/all"

module Foobara
  class RedisCrudDriver < Persistence::EntityAttributesCrudDriver
    class << self
      def reset_all
        if instance_variable_defined?(:@redis)
          # TODO: protect against this in production
          redis.flushdb
          remove_instance_variable(:@redis)
        end
      end
    end
  end
end

Foobara::Util.require_directory("#{__dir__}/../../src")
