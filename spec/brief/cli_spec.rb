# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'skywatch brief CLI' do
  let(:brief) do
    instance_double(
      Skywatch::Brief::Models::Brief,
      to_h: { airport: 'KCDW', aim_section: '7-1-5' }
    )
  end

  before { allow(Skywatch).to receive(:brief).with(airport: 'KCDW').and_return(brief) }

  it 'prints the brief as JSON' do
    output = capture_stdout { Skywatch::CLI.start(%w[brief KCDW]) }
    parsed = JSON.parse(output)
    expect(parsed['airport']).to eq('KCDW')
    expect(parsed['aim_section']).to eq('7-1-5')
  end

  it 'exits non-zero on Skywatch::Error' do
    allow(Skywatch).to receive(:brief).and_raise(Skywatch::Error, 'no METAR for KZZZ')
    expect { Skywatch::CLI.start(%w[brief KZZZ]) }.to raise_error(SystemExit) do |e|
      expect(e.status).not_to eq(0)
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
end
