# frozen_string_literal: true

module Skywatch
  module Shared
    class Cache
      def initialize(client:)
        @client = client
        @store = {}
        @mutex = Mutex.new
      end

      def get(path, params = {}, ttl: 300)
        key = cache_key(path, params)

        @mutex.synchronize do
          entry = @store[key]
          return entry[:data] if entry && !expired?(entry, ttl)
        end

        data = @client.get(path, params)

        @mutex.synchronize do
          @store[key] = { data: data, cached_at: Time.now }
        end

        data
      end

      def get_raw(path, params = {}, ttl: 300)
        key = cache_key(path, params)

        @mutex.synchronize do
          entry = @store[key]
          return entry[:data] if entry && !expired?(entry, ttl)
        end

        data = @client.get_raw(path, params)

        @mutex.synchronize do
          @store[key] = { data: data, cached_at: Time.now }
        end

        data
      end

      def clear
        @mutex.synchronize { @store.clear }
      end

      def size
        @mutex.synchronize { @store.size }
      end

      private

      def cache_key(path, params)
        [path, params.sort_by { |k, _| k.to_s }].to_s
      end

      def expired?(entry, ttl)
        Time.now - entry[:cached_at] > ttl
      end
    end
  end
end
