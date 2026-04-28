# frozen_string_literal: true

require 'thor'
require 'json'

module Skywatch
  class CLI < Thor
    desc 'weather SUBCOMMAND', 'Aviation weather briefings'
    subcommand 'weather', Skywatch::Briefer::CLI

    desc 'radar SUBCOMMAND', 'Flight tracking'
    subcommand 'radar', Skywatch::Radar::CLI

    desc 'mayday SUBCOMMAND', 'Emergency-squawk detection (7500/7600/7700)'
    subcommand 'mayday', Skywatch::Mayday::CLI

    desc 'nimbus SUBCOMMAND', 'SPC convective outlooks and storm reports'
    subcommand 'nimbus', Skywatch::Nimbus::CLI

    desc 'brief AIRPORT', 'AIM 7-1-5 weather brief composed for AIRPORT'
    def brief(airport)
      result = Skywatch.brief(airport: airport)
      puts JSON.pretty_generate(result.to_h)
    rescue Skywatch::Error => e
      warn "Error: #{e.message}"
      exit 1
    end

    desc 'version', 'Print version'
    def version
      puts "skywatch #{Skywatch::VERSION}"
    end
  end
end
