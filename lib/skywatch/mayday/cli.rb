# frozen_string_literal: true

require 'thor'
require 'json'

module Skywatch
  module Mayday
    class CLI < Thor
      class_option :format, type: :string, enum: %w[text json],
                            desc: 'Output format (default: text on TTY, json when piped)'

      desc 'near LAT LON', 'Aircraft squawking emergency (7500/7600/7700) within radius'
      option :radius, type: :numeric, default: 100, desc: 'Search radius in NM'
      def near(lat, lon) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
        emergencies = Skywatch.mayday(lat: lat.to_f, lon: lon.to_f, radius_nm: options[:radius])

        if emergencies.empty?
          if output_format == 'json'
            puts '[]'
          else
            puts "No emergencies within #{options[:radius]}nm of #{lat}, #{lon}"
          end
          return
        end

        if output_format == 'json'
          puts JSON.pretty_generate(emergencies.map(&:to_h))
        else
          emergencies.each { |e| print Skywatch::Mayday::Formatters::Text.format_emergency(e) }
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
