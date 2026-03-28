# frozen_string_literal: true

require "thor"
require "json"

module Briefer
  class CLI < Thor
    class_option :format, type: :string, enum: %w[text json],
                          desc: "Output format (default: text on TTY, json when piped)"

    desc "metar STATION [STATION...]", "Fetch current METAR(s)"
    option :raw, type: :boolean, desc: "Show raw METAR string only"
    def metar(*stations)
      metars = Briefer.metar(*stations)
      print_metars(metars)
    rescue Briefer::Error => e
      warn "Error: #{e.message}"
      exit 1
    end

    desc "categories STATION [STATION...]", "Check flight categories"
    def categories(*stations)
      metars = Briefer.metar(*stations)

      if output_format == "json"
        result = metars.to_h { |m| [m.station_id, m.flight_category.to_s] }
        puts JSON.pretty_generate(result)
      else
        metars.each { |m| print Formatters::Text.format_category(m) }
      end
    rescue Briefer::Error => e
      warn "Error: #{e.message}"
      exit 1
    end

    private

    def print_metars(metars)
      if options[:raw]
        metars.each { |m| puts m.raw }
      elsif output_format == "json"
        puts JSON.pretty_generate(metars.map(&:to_h))
      else
        metars.each { |m| print Formatters::Text.format_metar(m) }
      end
    end

    def output_format
      options[:format] || ($stdout.tty? ? "text" : "json")
    end
  end
end
