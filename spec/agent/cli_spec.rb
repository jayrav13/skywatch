# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'

RSpec.describe 'skywatch agent CLI' do
  around do |ex|
    Dir.mktmpdir do |dir|
      ENV['SKYWATCH_AGENTS_DIR'] = dir
      ex.run
      ENV.delete('SKYWATCH_AGENTS_DIR')
    end
  end

  describe 'install' do
    let(:dest) { File.join(ENV.fetch('SKYWATCH_AGENTS_DIR'), 'skywatch.md') }

    it 'copies the bundled agent file to the agents directory' do
      output = capture_stdout { Skywatch::CLI.start(%w[agent install --yes]) }
      expect(File.exist?(dest)).to be true
      content = File.read(dest)
      expect(content).to start_with('---')
      expect(content).to include('name: skywatch')
      expect(content).to include('aviation weather briefer')
      expect(output).to include(dest)
    end

    it 'creates the agents directory if it does not exist' do
      nested = File.join(ENV.fetch('SKYWATCH_AGENTS_DIR'), 'nested', 'agents')
      ENV['SKYWATCH_AGENTS_DIR'] = nested
      capture_stdout { Skywatch::CLI.start(%w[agent install --yes]) }
      expect(Dir.exist?(nested)).to be true
      expect(File.exist?(File.join(nested, 'skywatch.md'))).to be true
    end

    it 'overwrites without prompting when --yes is given' do
      File.write(dest, 'OLD')
      capture_stdout { Skywatch::CLI.start(%w[agent install --yes]) }
      expect(File.read(dest)).not_to eq('OLD')
      expect(File.read(dest)).to include('name: skywatch')
    end

    it 'skips overwrite when destination exists and --yes is not given' do
      File.write(dest, 'OLD')
      output = capture_stdout do
        capture_stdin('n') { Skywatch::CLI.start(%w[agent install]) }
      end
      expect(File.read(dest)).to eq('OLD')
      expect(output).to match(/exists|skipped/i)
    end

    it 'overwrites when destination exists and the user answers yes interactively' do
      File.write(dest, 'OLD')
      capture_stdout do
        capture_stdin('y') { Skywatch::CLI.start(%w[agent install]) }
      end
      expect(File.read(dest)).to include('name: skywatch')
    end
  end

  def capture_stdout
    old = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = old
  end

  def capture_stdin(input)
    old = $stdin
    $stdin = StringIO.new("#{input}\n")
    yield
  ensure
    $stdin = old
  end
end
