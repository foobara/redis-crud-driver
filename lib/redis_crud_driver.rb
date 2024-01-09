require "redis"

require "foobara/all"

module Foobara
  class RedisCrudDriver < Persistence::EntityAttributesCrudDriver
  end
end

Foobara::Util.require_directory("#{__dir__}/../src")
