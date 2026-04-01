# frozen_string_literal: true

require 'thor'
require 'json'

module Skywatch
  module Radar
    class CLI < Thor
      class_option :format, type: :string, enum: %w[text json],
                            desc: 'Output format (default: text on TTY, json when piped)'

      desc 'flights LAT LON', 'Active flights near coordinates'
      option :radius, type: :numeric, default: 50, desc: 'Search radius in NM'
      def flights(lat, lon) # rubocop:disable Metrics/AbcSize
        nearby = Skywatch.flights(lat: lat.to_f, lon: lon.to_f, radius_nm: options[:radius])

        if output_format == 'json'
          puts JSON.pretty_generate(nearby.map(&:to_h))
        else
          label = "#{lat}, #{lon} (#{options[:radius]}nm)"
          print Skywatch::Radar::Formatters::Text.format_flights_table(nearby, label: label)
        end
      rescue Skywatch::Error => e
        warn "Error: #{e.message}"
        exit 1
      end

      desc 'track CALLSIGN', 'Track flight by callsign'
      def track(callsign) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
        vectors = Skywatch.track(callsign)

        if vectors.empty?
          if output_format == 'json'
            puts '[]'
          else
            puts "No aircraft found with callsign #{callsign.upcase}"
          end
          return
        end

        if output_format == 'json'
          puts JSON.pretty_generate(vectors.map(&:to_h))
        else
          vectors.each { |sv| print Skywatch::Radar::Formatters::Text.format_track(sv) }
        end
      rescue Skywatch::Error => e
        warn "Error: #{e.message}"
        exit 1
      end

      desc 'aircraft ICAO24', 'Lookup by ICAO24 hex address'
      def aircraft(icao24) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
        vectors = Skywatch.aircraft(icao24)

        if vectors.empty?
          if output_format == 'json'
            puts '[]'
          else
            puts "No aircraft found with ICAO24 #{icao24}"
          end
          return
        end

        if output_format == 'json'
          puts JSON.pretty_generate(vectors.map(&:to_h))
        else
          vectors.each { |sv| print Skywatch::Radar::Formatters::Text.format_track(sv) }
        end
      rescue Skywatch::Error => e
        warn "Error: #{e.message}"
        exit 1
      end

      private

      def output_format
        options[:format] || ($stdout.tty? ? 'text' : 'json')
      end
    end
  end
end
