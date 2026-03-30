# frozen_string_literal: true

require_relative "skywatch/version"
require_relative "skywatch/shared/errors"
require_relative "skywatch/shared/position"
require_relative "skywatch/shared/http"
require_relative "skywatch/shared/cache"
require_relative "skywatch/shared/geometry"

module Skywatch
  class << self
    def client
      @client ||= Shared::Cache.new(client: Shared::Http.new)
    end

    def reset!
      @client = nil
    end
  end
end
