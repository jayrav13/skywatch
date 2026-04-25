# frozen_string_literal: true

require 'time'

module Skywatch
  module Nimbus
    module Models
      class Convection
        SEVERITY_RANK = { extreme: 4, severe: 3, moderate: 2, minor: 1, unknown: 0 }.freeze

        attr_reader :at, :fetched_at, :alerts

        def initialize(at:, fetched_at:, alerts:)
          @at = at
          @fetched_at = fetched_at
          @alerts = alerts
        end

        def warnings
          alerts.select(&:warning?)
        end

        def watches
          alerts.select(&:watch?)
        end

        def active?
          !alerts.empty?
        end

        def max_severity
          return nil if alerts.empty?

          alerts.max_by { |a| SEVERITY_RANK.fetch(a.severity, 0) }.severity
        end

        def to_h
          {
            at: at,
            fetched_at: fetched_at&.iso8601,
            warnings: warnings.map(&:to_h),
            watches: watches.map(&:to_h)
          }
        end

        def to_json(*)
          to_h.to_json(*)
        end
      end
    end
  end
end
