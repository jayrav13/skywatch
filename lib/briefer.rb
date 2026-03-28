# frozen_string_literal: true

require_relative "briefer/version"
require_relative "briefer/errors"
require_relative "briefer/client/http"
require_relative "briefer/models/position"
require_relative "briefer/analysis/flight_category"

module Briefer
  class << self
    def client
      @client ||= Client::Http.new
    end

    def reset!
      @client = nil
    end
  end
end
