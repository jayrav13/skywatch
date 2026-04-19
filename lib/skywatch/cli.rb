# frozen_string_literal: true

require 'thor'

module Skywatch
  class CLI < Thor
    desc 'weather SUBCOMMAND', 'Aviation weather briefings'
    subcommand 'weather', Skywatch::Briefer::CLI

    desc 'radar SUBCOMMAND', 'Flight tracking'
    subcommand 'radar', Skywatch::Radar::CLI

    desc 'mayday SUBCOMMAND', 'Emergency-squawk detection (7500/7600/7700)'
    subcommand 'mayday', Skywatch::Mayday::CLI

    desc 'version', 'Print version'
    def version
      puts "skywatch #{Skywatch::VERSION}"
    end
  end
end
