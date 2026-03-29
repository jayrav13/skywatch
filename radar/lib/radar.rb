# frozen_string_literal: true

require_relative 'radar/version'
require_relative 'radar/errors'

module Radar
  class << self
    def version
      VERSION
    end
  end
end
