# frozen_string_literal: true

require 'thor'
require 'json'

module Skywatch
  module Briefer
    class CLI < Thor # rubocop:disable Metrics/ClassLength
      class_option :format, type: :string, enum: %w[text json],
                            desc: 'Output format (default: text on TTY, json when piped)'

      desc 'metar STATION [STATION...]', 'Fetch current METAR(s)'
      option :raw, type: :boolean, desc: 'Show raw METAR string only'
      def metar(*stations)
        metars = Skywatch.metar(*stations)
        print_metars(metars)
      rescue Skywatch::Error => e
        warn "Error: #{e.message}"
        exit 1
      end

      desc 'taf STATION [STATION...]', 'Fetch current TAF(s)'
      def taf(*stations)
        tafs = Skywatch.taf(*stations)

        if output_format == 'json'
          puts JSON.pretty_generate(tafs.map(&:to_h))
        else
          tafs.each { |t| print Skywatch::Briefer::Formatters::Text.format_taf(t) }
        end
      rescue Skywatch::Error => e
        warn "Error: #{e.message}"
        exit 1
      end

      desc 'pireps STATION', 'Fetch recent PIREPs near station'
      option :radius, type: :numeric, default: 100, desc: 'Search radius in NM'
      def pireps(station) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        reports = Skywatch.pireps(station, radius_nm: options[:radius])

        if output_format == 'json'
          puts JSON.pretty_generate(reports.map(&:to_h))
        elsif reports.empty?
          puts "No PIREPs within #{options[:radius]}nm of #{station.upcase}"
        else
          puts "PIREPs within #{options[:radius]}nm of #{station.upcase}:"
          reports.each { |p| print Skywatch::Briefer::Formatters::Text.format_pirep(p) }
        end
      rescue Skywatch::Error => e
        warn "Error: #{e.message}"
        exit 1
      end

      desc 'winds STATION', 'Fetch winds aloft forecast'
      option :altitude, type: :numeric, desc: 'Filter to specific altitude (feet)'
      def winds(station)
        winds = Skywatch.winds_aloft(station, altitude_ft: options[:altitude])

        if output_format == 'json'
          puts JSON.pretty_generate(winds.map(&:to_h))
        else
          puts "Winds aloft for #{station.upcase}:"
          print Skywatch::Briefer::Formatters::Text.format_winds_aloft(winds)
        end
      rescue Skywatch::Error => e
        warn "Error: #{e.message}"
        exit 1
      end

      desc 'crosswind STATION', 'Calculate crosswind component'
      option :runway, type: :numeric, required: true, desc: 'Runway heading (degrees)'
      def crosswind(station)
        result = Skywatch.crosswind(station, runway_heading: options[:runway])

        if output_format == 'json'
          puts JSON.pretty_generate(result)
        else
          print Skywatch::Briefer::Formatters::Text.format_crosswind(result, station.upcase, options[:runway])
        end
      rescue Skywatch::Error => e
        warn "Error: #{e.message}"
        exit 1
      end

      desc 'sigmets', 'List all active SIGMETs'
      def sigmets # rubocop:disable Metrics/MethodLength
        sigs = Skywatch.sigmets

        if output_format == 'json'
          puts JSON.pretty_generate(sigs.map(&:to_h))
        elsif sigs.empty?
          puts 'No active SIGMETs'
        else
          sigs.each { |s| print Skywatch::Briefer::Formatters::Text.format_sigmet(s) }
        end
      rescue Skywatch::Error => e
        warn "Error: #{e.message}"
        exit 1
      end

      desc 'airmets', 'List all active AIRMETs'
      option :product, type: :string, enum: %w[sierra tango zulu],
                       desc: 'Filter by product type (sierra/tango/zulu)'
      def airmets # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        all = Skywatch.airmets
        all = all.select { |a| a.product.to_s == options[:product] } if options[:product]

        if output_format == 'json'
          puts JSON.pretty_generate(all.map(&:to_h))
        elsif all.empty?
          puts 'No active AIRMETs'
        else
          all.each { |a| print Skywatch::Briefer::Formatters::Text.format_airmet(a) }
        end
      rescue Skywatch::Error => e
        warn "Error: #{e.message}"
        exit 1
      end

      desc 'categories STATION [STATION...]', 'Check flight categories'
      def categories(*stations)
        metars = Skywatch.metar(*stations)

        if output_format == 'json'
          result = metars.to_h { |m| [m.station_id, m.flight_category.to_s] }
          puts JSON.pretty_generate(result)
        else
          metars.each { |m| print Skywatch::Briefer::Formatters::Text.format_category(m) }
        end
      rescue Skywatch::Error => e
        warn "Error: #{e.message}"
        exit 1
      end

      private

      def print_metars(metars)
        if options[:raw]
          metars.each { |m| puts m.raw }
        elsif output_format == 'json'
          puts JSON.pretty_generate(metars.map(&:to_h))
        else
          metars.each { |m| print Skywatch::Briefer::Formatters::Text.format_metar(m) }
        end
      end

      def output_format
        options[:format] || ($stdout.tty? ? 'text' : 'json')
      end
    end
  end
end
