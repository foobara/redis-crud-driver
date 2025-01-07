require "json"

module Foobara
  class RedisCrudDriver < Persistence::EntityAttributesCrudDriver
    class NoRedisUrlError < StandardError; end

    class << self
      attr_writer :redis

      def redis
        @redis ||= if ENV["REDIS_URL"]
                     Redis.new(url: ENV["REDIS_URL"])
                   else
                     raise NoRedisUrlError,
                           'Must set ENV["REDIS_URL"] if trying to initialize RedisCrudDriver with no arguments'
                   end
      end
    end

    attr_reader :prefix

    # TODO: maybe we should distinguish between nil being passed in and no args? nil feels like it could be an error.
    def initialize(connection_or_credentials = nil, prefix: nil)
      @prefix = prefix
      super(connection_or_credentials)
    end

    def open_connection(connection_url_or_credentials)
      case connection_url_or_credentials
      when Redis
        connection_url_or_credentials
      when ::String
        Redis.new(url: connection_url_or_credentials)
      when ::Hash
        Redis.new(connection_url_or_credentials)
      when nil
        self.class.redis
      end
    end

    class Table < Persistence::EntityAttributesCrudDriver::Table
      def initialize(...)
        super

        unless entity_class.primary_key_type.type_symbol == :integer
          # TODO: when primary key is a string such as a uuid we should
          # probably set the score to 0 and use other methods. But not interested in implementing that stuff now.
          # :nocov:
          raise "Only integer primary keys are supported for now"
          # :nocov:
        end
      end

      def get_id
        redis.incr(sequence_key)
      end

      def all
        Enumerator.new do |yielder|
          batches_of_primary_keys.each do |batch|
            raw_records = redis.pipelined do |p|
              batch.each do |record_id|
                p.hgetall(record_key_prefix(record_id))
              end
            end

            raw_records.each do |raw_record|
              yielder << restore_attributes_from_redis(raw_record)
            end
          end
        end.lazy
      end

      def count
        redis.zcount(primary_keys_index_key, "-inf", "+inf")
      end

      def find(record_id)
        pairs = redis.hgetall(record_key_prefix(record_id))

        unless pairs.empty?
          restore_attributes_from_redis(pairs.to_h)
        end
      end

      # TODO: move this up to base class as a default
      def find!(record_id)
        attributes = find(record_id)

        unless attributes
          raise CannotFindError.new(record_id, "does not exist")
        end

        attributes
      end

      def insert(attributes)
        attributes = Util.deep_dup(attributes)

        record_id = record_id_for(attributes)

        if record_id
          # TODO: implement exists? using redis instead of super's find
          if exists?(record_id)
            raise CannotInsertError.new(record_id, "already exists")
          end
        else
          record_id = get_id
          attributes.merge!(primary_key_attribute => record_id)
        end

        prepare_attributes_for_redis(attributes)

        # TODO: use redis.multi here
        redis.hset(record_key_prefix(record_id), attributes)
        redis.zadd(primary_keys_index_key, record_id, record_id)
        find(record_id)
      end

      def update(attributes)
        record_id = record_id_for(attributes)

        unless exists?(record_id)
          # :nocov:
          raise CannotUpdateError.new(record_id, "does not exist")
          # :nocov:
        end

        attributes = prepare_attributes_for_redis(Util.deep_dup(attributes))

        redis.hset(record_key_prefix(record_id), attributes)
        find(record_id)
      end

      def hard_delete(record_id)
        # TODO: add multi
        key = record_key_prefix(record_id)

        if redis.del(key) != 1
          # :nocov:
          raise CannotUpdateError.new(record_id, "#{key} does not exist")
          # :nocov:
        end

        unless redis.zrem(primary_keys_index_key, record_id)
          # :nocov:
          raise "Unexpected: when deleting #{key}, " \
                "#{record_id} was not present in the primary key index for #{primary_keys_index_key}"
          # :nocov:
        end
      end

      def hard_delete_all
        batches_of_primary_keys.each do |batch|
          redis.pipelined do |p|
            batch.each do |record_id|
              p.del(record_key_prefix(record_id))
              p.zrem(primary_keys_index_key, record_id)
            end
          end
        end
      end

      private

      def prefix
        crud_driver.prefix
      end

      def sequence_key
        @sequence_key ||= "#{entity_key_prefix}$sequence"
      end

      def primary_keys_index_key
        @primary_keys_index_key ||= "#{entity_key_prefix}$all"
      end

      def entity_key_prefix
        @entity_key_prefix ||= [*prefix, table_name].join(":")
      end

      def record_key_prefix(record_id)
        "#{entity_key_prefix}:#{record_id}"
      end

      def redis
        raw_connection
      end

      def prepare_attributes_for_redis(attributes)
        attributes.transform_values! do |value|
          JSON.fast_generate(value)
        end
      end

      def restore_attributes_from_redis(attributes)
        attributes.to_h do |attribute_name, value|
          [attribute_name.to_sym, JSON.parse(value)]
        end
      end

      def batches_of_primary_keys
        limit = [0, 50]

        lower_bound = 0

        Enumerator.new do |yielder|
          loop do
            batch = redis.zrangebyscore(primary_keys_index_key, lower_bound, "+inf", limit:)

            break if batch.empty?

            yielder << batch

            lower_bound = batch.last.to_i + 1
          end
        end.lazy
      end
    end
  end
end
