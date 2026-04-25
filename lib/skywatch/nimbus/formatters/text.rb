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

        SEVERITY_RANK = { extreme: 4, severe: 3, moderate: 2, minor: 1, unknown: 0 }.freeze

        def self.format_convection(convection)
          return "NO ACTIVE CONVECTIVE WARNINGS OR WATCHES.\n" unless convection.active?

          ordered = order_alerts(convection.alerts)
          ordered.map { |a| format_alert(a) }.join
        end

        def self.order_alerts(alerts)
          warnings = alerts.select(&:warning?).sort_by.with_index { |a, i| [-SEVERITY_RANK.fetch(a.severity, 0), i] }
          watches  = alerts.select(&:watch?).sort_by.with_index { |a, i| [-SEVERITY_RANK.fetch(a.severity, 0), i] }
          warnings + watches
        end

        def self.format_alert(alert)
          number = alert.watch? ? watch_number(alert) : nil
          number_part = number ? " ##{number}" : ''
          base = "#{alert.event.upcase}#{number_part} — #{alert.area_description} #{until_phrase(alert)}."
          extras = build_extras(alert)
          extras.empty? ? "#{base}\n" : "#{base} #{extras}\n"
        end

        def self.build_extras(alert)
          parts = []
          parts << tornado_phrase(alert) if tornado_phrase(alert)

          measurements = [hail_phrase(alert), wind_gust_phrase(alert)].compact
          parts << measurements.join(', ') unless measurements.empty?

          parts << damage_threat_phrase(alert) if damage_threat_phrase(alert)

          parts.empty? ? '' : "#{parts.join('; ')}."
        end

        def self.until_phrase(alert)
          "until #{alert.expires_at.utc.strftime('%H:%MZ')}"
        end

        def self.hail_phrase(alert)
          return nil if alert.hail_size_in.nil?

          format('%<size>.2f" hail', size: alert.hail_size_in)
        end

        def self.wind_gust_phrase(alert)
          return nil if alert.wind_gust_kt.nil?

          "#{alert.wind_gust_kt.round}kt wind gust"
        end

        def self.tornado_phrase(alert)
          case alert.tornado_detection
          when :observed        then 'Tornado observed'
          when :radar_indicated then 'Radar-indicated'
          end
        end

        def self.damage_threat_phrase(alert)
          threat = alert.thunderstorm_damage_threat || alert.flash_flood_damage_threat
          return nil if threat.nil?

          "#{threat.to_s.capitalize} damage threat"
        end

        def self.watch_number(alert)
          match = alert.headline.to_s.match(/\b(?:Tornado|Severe Thunderstorm) Watch (\d+)\b/)
          match ? match[1].to_i : nil
        end

        private_class_method :format_time, :label_for, :magnitude_label,
                             :until_phrase, :hail_phrase, :wind_gust_phrase,
                             :tornado_phrase, :damage_threat_phrase, :watch_number,
                             :order_alerts, :format_alert, :build_extras
      end
    end
  end
end
