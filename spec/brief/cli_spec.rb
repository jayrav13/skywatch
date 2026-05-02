# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'skywatch brief CLI' do
  let(:brief) do
    instance_double(
      Skywatch::Brief::Models::Brief,
      to_h: { airport: 'KCDW', aim_section: '7-1-5' }
    )
  end

  before { allow(Skywatch).to receive(:brief).with(airport: 'KCDW', departing_at: nil).and_return(brief) }

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

  it 'parses LAT,LON target into a coordinate brief' do
    coord_brief = instance_double(
      Skywatch::Brief::Models::Brief,
      to_h: { airport: 'KCDW', coordinates: [40.688, -74.174], aim_section: '7-1-5' }
    )
    allow(Skywatch).to receive(:brief).with(at: [40.688, -74.174], departing_at: nil).and_return(coord_brief)
    output = capture_stdout { Skywatch::CLI.start(['brief', '40.688,-74.174']) }
    parsed = JSON.parse(output)
    expect(parsed['coordinates']).to eq([40.688, -74.174])
  end

  it 'exits non-zero when LAT,LON cannot be parsed as floats' do
    expect { Skywatch::CLI.start(['brief', '40.688,not-a-number']) }
      .to raise_error(SystemExit) { |e| expect(e.status).not_to eq(0) }
  end

  context '--departing-at option' do
    let(:etd) { Time.parse('2026-05-01T16:00:00Z') }

    it 'passes departing_at to Skywatch.brief when --departing-at is given' do
      expect(Skywatch).to receive(:brief)
        .with(airport: 'KCDW', departing_at: etd)
        .and_return(brief)
      capture_stdout { Skywatch::CLI.start(['brief', 'KCDW', '--departing-at', '2026-05-01T16:00:00Z']) }
    end

    it 'passes departing_at with coordinate input' do
      coord_brief = instance_double(
        Skywatch::Brief::Models::Brief,
        to_h: { airport: 'KCDW', coordinates: [40.688, -74.174], aim_section: '7-1-5' }
      )
      expect(Skywatch).to receive(:brief)
        .with(at: [40.688, -74.174], departing_at: etd)
        .and_return(coord_brief)
      capture_stdout do
        Skywatch::CLI.start(['brief', '40.688,-74.174', '--departing-at', '2026-05-01T16:00:00Z'])
      end
    end

    it 'exits non-zero when --departing-at cannot be parsed' do
      expect { Skywatch::CLI.start(['brief', 'KCDW', '--departing-at', 'not-a-time']) }
        .to raise_error(SystemExit) { |e| expect(e.status).not_to eq(0) }
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
