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

    desc "taf STATION [STATION...]", "Fetch current TAF(s)"
    def taf(*stations)
      tafs = Briefer.taf(*stations)

      if output_format == "json"
        puts JSON.pretty_generate(tafs.map(&:to_h))
      else
        tafs.each { |t| print Formatters::Text.format_taf(t) }
      end
    rescue Briefer::Error => e
      warn "Error: #{e.message}"
      exit 1
    end

    desc "pireps STATION", "Fetch recent PIREPs near station"
    option :radius, type: :numeric, default: 100, desc: "Search radius in NM"
    def pireps(station) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      reports = Briefer.pireps(station, radius_nm: options[:radius])

      if output_format == "json"
        puts JSON.pretty_generate(reports.map(&:to_h))
      elsif reports.empty?
        puts "No PIREPs within #{options[:radius]}nm of #{station.upcase}"
      else
        puts "PIREPs within #{options[:radius]}nm of #{station.upcase}:"
        reports.each { |p| print Formatters::Text.format_pirep(p) }
      end
    rescue Briefer::Error => e
      warn "Error: #{e.message}"
      exit 1
    end

    desc "winds STATION", "Fetch winds aloft forecast"
    option :altitude, type: :numeric, desc: "Filter to specific altitude (feet)"
    def winds(station)
      winds = Briefer.winds_aloft(station, altitude_ft: options[:altitude])

      if output_format == "json"
        puts JSON.pretty_generate(winds.map(&:to_h))
      else
        puts "Winds aloft for #{station.upcase}:"
        print Formatters::Text.format_winds_aloft(winds)
      end
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
