# frozen_string_literal: true

module Skywatch
  module Nimbus
    module Models
      class Outlook
        RISK_LEVELS = {
          'TSTM' => { level: :general_thunder, score: 1, description: 'General Thunderstorms' },
          'MRGL' => { level: :marginal,        score: 2, description: 'Marginal Risk' },
          'SLGT' => { level: :slight,          score: 3, description: 'Slight Risk' },
          'ENH'  => { level: :enhanced,        score: 4, description: 'Enhanced Risk' },
          'MDT'  => { level: :moderate,        score: 5, description: 'Moderate Risk' },
          'HIGH' => { level: :high,            score: 6, description: 'High Risk' }
        }.freeze

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

        def risk_level
          RISK_LEVELS.fetch(label)[:level]
        end

        def risk_score
          RISK_LEVELS.fetch(label)[:score]
        end

        def description
          RISK_LEVELS.fetch(label)[:description]
        end
      end
    end
  end
end
