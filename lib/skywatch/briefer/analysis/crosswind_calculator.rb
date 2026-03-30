# frozen_string_literal: true

module Skywatch
  module Briefer
    module Analysis
      module CrosswindCalculator
        def self.calculate(wind_direction_deg:, wind_speed_kt:, runway_heading:)
          return { crosswind_kt: 0.0, headwind_kt: 0.0 } if wind_speed_kt.zero?

          angle_rad = (wind_direction_deg - runway_heading) * Math::PI / 180.0

          {
            crosswind_kt: (wind_speed_kt * Math.sin(angle_rad)).abs.round(1),
            headwind_kt: (wind_speed_kt * Math.cos(angle_rad)).round(1)
          }
        end
      end
    end
  end
end
