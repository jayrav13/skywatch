# frozen_string_literal: true

require 'date'
require 'time'
require 'json'

module Skywatch
  module Nimbus
    module Models
      class StormReport
        MPH_TO_KT = 0.868976

        attr_reader :time, :type, :magnitude, :magnitude_raw,
                    :location, :county, :state,
                    :latitude, :longitude, :comments

        def self.from_spc_row(row, type:, report_date:) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
          hhmm, mag_raw, location, county, state, lat, lon, comments = row
          new(
            time: parse_time(report_date, hhmm),
            type: type,
            magnitude: parse_magnitude(mag_raw, type: type),
            magnitude_raw: mag_raw.to_s,
            location: location,
            county: county,
            state: state,
            latitude: lat.to_f,
            longitude: lon.to_f,
            comments: comments.to_s
          )
        end

        def initialize(time:, type:, magnitude:, magnitude_raw:,
                       location:, county:, state:,
                       latitude:, longitude:, comments:)
          @time = time
          @type = type
          @magnitude = magnitude
          @magnitude_raw = magnitude_raw
          @location = location
          @county = county
          @state = state
          @latitude = latitude
          @longitude = longitude
          @comments = comments
        end

        def wind_kt
          return nil unless type == :wind && magnitude

          (magnitude * MPH_TO_KT).round(2)
        end

        def to_h
          {
            time: time&.iso8601,
            type: type,
            magnitude: magnitude,
            magnitude_raw: magnitude_raw,
            location: location,
            county: county,
            state: state,
            latitude: latitude,
            longitude: longitude,
            comments: comments
          }
        end

        def to_json(*)
          to_h.to_json(*)
        end

        def self.parse_time(report_date, hhmm)
          return nil if hhmm.nil? || hhmm.empty?

          hh = hhmm[0..1].to_i
          mm = hhmm[2..3].to_i
          Time.utc(report_date.year, report_date.month, report_date.day, hh, mm)
        end

        def self.parse_magnitude(raw, type:)
          return nil if raw.nil? || raw.to_s.strip.empty?

          case type
          when :tornado then nil
          when :wind
            raw.to_s.match?(/\A-?\d+(\.\d+)?\z/) ? raw.to_f : nil
          when :hail
            raw.to_s.match?(/\A\d+\z/) ? raw.to_i / 100.0 : nil
          end
        end

        private_class_method :parse_time, :parse_magnitude
      end
    end
  end
end
