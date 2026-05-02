# frozen_string_literal: true

require 'thor'
require 'fileutils'

module Skywatch
  module Agent
    class CLI < Thor
      AGENT_FILENAME = 'skywatch.md'

      desc 'install', 'Install the skywatch subagent into ~/.claude/agents/'
      method_option :yes, type: :boolean, default: false, aliases: '-y',
                          desc: 'Overwrite existing file without prompting'
      def install # rubocop:disable Metrics/AbcSize
        FileUtils.mkdir_p(agents_dir)

        if File.exist?(destination) && !options[:yes] && !confirm_overwrite?
          puts "Skipped: #{destination} already exists. Use --yes to overwrite."
          return
        end

        FileUtils.cp(source, destination)
        puts "Installed: #{destination}"
        puts 'Restart Claude Code (or open a new session) to pick up the agent.'
      end

      private

      def source
        File.expand_path('../../../agents/skywatch.md', __dir__)
      end

      def destination
        File.join(agents_dir, AGENT_FILENAME)
      end

      def agents_dir
        ENV['SKYWATCH_AGENTS_DIR'] || File.expand_path('~/.claude/agents')
      end

      def confirm_overwrite?
        print "#{destination} exists. Overwrite? [y/N] "
        answer = $stdin.gets.to_s.strip.downcase
        %w[y yes].include?(answer)
      end
    end
  end
end
