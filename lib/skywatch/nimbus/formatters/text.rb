# frozen_string_literal: true

module Skywatch
  module Nimbus
    module Formatters
      module Text
        def self.format_outlook(outlook)
          valid = "#{format_time(outlook.valid_from)} → #{format_time(outlook.valid_to)}"
          forecaster = outlook.forecaster ? " (forecaster #{outlook.forecaster})" : ''
          "OUTLOOK DAY #{outlook.day}: #{outlook.label} (#{outlook.description}) — valid #{valid}#{forecaster}\n"
        end

        def self.format_storm_report(report)
          time = report.time ? report.time.strftime('%H:%MZ') : '--:--Z'
          loc = "#{report.location}, #{report.county} #{report.state}"
          coords = format('(%<lat>.2f, %<lon>.2f)', lat: report.latitude, lon: report.longitude)
          comments = report.comments.to_s.strip.empty? ? '' : " — #{report.comments.strip}"

          "#{label_for(report)} @ #{time} #{loc} #{coords}#{comments}\n"
        end

        def self.format_time(time)
          return '---' if time.nil?

          time.strftime('%Y-%m-%d %H:%MZ')
        end

        def self.label_for(report)
          magnitude_part = magnitude_label(report)

          case report.type
          when :tornado then "TORNADO #{magnitude_part}".rstrip
          when :wind    then "WIND #{magnitude_part}".rstrip
          when :hail    then "HAIL #{magnitude_part}".rstrip
          end
        end

        def self.magnitude_label(report)
          case report.type
          when :tornado
            report.magnitude_raw.to_s
          when :wind
            report.magnitude ? "#{report.magnitude.to_i}mph (kt ~#{report.wind_kt.to_i})" : report.magnitude_raw.to_s
          when :hail
            report.magnitude ? format('%<m>.2f"', m: report.magnitude) : report.magnitude_raw.to_s
          end
        end

        private_class_method :format_time, :label_for, :magnitude_label
      end
    end
  end
end
