# frozen_string_literal: true

module Briefer
  class Error < StandardError
    attr_reader :response

    def initialize(message = nil, response: nil)
      @response = response
      super(message)
    end
  end

  class ConnectionError < Error; end
  class ApiError < Error; end
  class ParseError < Error; end
end
