# frozen_string_literal: true

require 'thor'
require 'json'

module Skywatch
  module Nimbus
    class CLI < Thor
      class_option :format, type: :string, enum: %w[text json],
                            desc: 'Output format (default: text on TTY, json when piped)'

      # Thor treats any argv starting with `-` as an option, so `--at 40.7 -74.0`
      # loses the negative longitude. Rewrite such pairs into a single =-form
      # value so negative coordinates survive parsing.
      def self.start(given_args = ARGV, config = {})
        super(rewrite_point_args(given_args), config)
      end

      def self.rewrite_point_args(args) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        out = []
        i = 0
        point_flags = %w[--at --near]
        while i < args.length
          flag = args[i]
          if point_flags.include?(flag) && args[i + 1] && args[i + 2] &&
             numeric?(args[i + 1]) && numeric?(args[i + 2])
            out << "#{flag}=#{args[i + 1]},#{args[i + 2]}"
            i += 3
          else
            out << args[i]
            i += 1
          end
        end
        out
      end

      def self.numeric?(str)
        Float(str)
        true
      rescue ArgumentError, TypeError
        false
      end

      desc 'outlook DAY', 'SPC categorical convective outlook for day 1, 2, or 3'
      option :at, type: :string, desc: 'Point query: --at LAT LON — returns the covering outlook only'
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

      def output_format
        options[:format] || ($stdout.tty? ? 'text' : 'json')
      end
    end
  end
end
