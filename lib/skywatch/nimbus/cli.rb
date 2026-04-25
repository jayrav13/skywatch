# frozen_string_literal: true

require 'thor'
require 'json'
require 'date'

module Skywatch
  module Nimbus
    class CLI < Thor
      class_option :format, type: :string, enum: %w[text json],
                            desc: 'Output format (default: text on TTY, json when piped)'

      desc 'outlook DAY', 'SPC categorical convective outlook for day 1, 2, or 3'
      option :at, type: :string, desc: 'Point query: --at LAT,LON — returns the covering outlook only'
      def outlook(day) # rubocop:disable Metrics/MethodLength
        day_i = Integer(day)
        if options[:at]
          lat, lon = options[:at].split(',').map(&:to_f)
          result = Skywatch.outlook(day: day_i, at: [lat, lon])
          print_single_outlook(result, lat: lat, lon: lon)
        else
          outlooks = Skywatch.outlook(day: day_i)
          print_outlook_list(outlooks)
        end
      rescue Skywatch::Error => e
        warn "Error: #{e.message}"
        exit 1
      end

      desc 'storms', 'Recent SPC storm reports (tornado / wind / hail)'
      option :date, type: :string, desc: 'Report date YYYYMMDD (default: today)'
      option :type, type: :string, enum: %w[tornado wind hail],
                    desc: 'Filter to one report type'
      option :near, type: :string, desc: 'Point filter: --near LAT,LON'
      option :radius, type: :numeric, default: 100, desc: 'Radius in NM (used with --near)'
      def storms # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        date = options[:date] ? Date.strptime(options[:date], '%Y%m%d') : nil
        type = options[:type]&.to_sym
        near = if options[:near]
                 lat, lon = options[:near].split(',').map(&:to_f)
                 { lat: lat, lon: lon, radius_nm: options[:radius] }
               end

        reports = Skywatch.storms(date: date, type: type, near: near)
        print_storm_reports(reports)
      rescue Skywatch::Error => e
        warn "Error: #{e.message}"
        exit 1
      end

      private

      def print_outlook_list(outlooks)
        if output_format == 'json'
          puts JSON.pretty_generate(outlooks.map(&:to_h))
        else
          outlooks.each { |o| print Skywatch::Nimbus::Formatters::Text.format_outlook(o) }
        end
      end

      def print_single_outlook(outlook, lat:, lon:)
        if output_format == 'json'
          puts(outlook ? JSON.pretty_generate(outlook.to_h) : 'null')
        elsif outlook.nil?
          puts "No outlook covers #{lat}, #{lon}"
        else
          print Skywatch::Nimbus::Formatters::Text.format_outlook(outlook)
        end
      end

      def print_storm_reports(reports)
        if output_format == 'json'
          puts(reports.empty? ? '[]' : JSON.pretty_generate(reports.map(&:to_h)))
        elsif reports.empty?
          puts 'No storm reports'
        else
          reports.each { |r| print Skywatch::Nimbus::Formatters::Text.format_storm_report(r) }
        end
      end

      def output_format
        options[:format] || ($stdout.tty? ? 'text' : 'json')
      end
    end
  end
end
