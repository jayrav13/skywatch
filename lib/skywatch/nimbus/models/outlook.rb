# frozen_string_literal: true

module Skywatch
  module Nimbus
    module Models
      class Outlook
        attr_reader :day, :label, :valid_from, :valid_to, :issued_at, :forecaster, :geometry

        def initialize(day:, label:, valid_from:, valid_to:, issued_at:, forecaster:, geometry:)
          @day = day
          @label = label
          @valid_from = valid_from
          @valid_to = valid_to
          @issued_at = issued_at
          @forecaster = forecaster
          @geometry = geometry
        end
      end
    end
  end
end
