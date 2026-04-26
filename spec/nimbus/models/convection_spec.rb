# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Skywatch::Nimbus::Models::Convection do
  let(:warning) do
    Skywatch::Nimbus::Models::ConvectiveAlert.new(
      kind: :warning, severity: :extreme, event: 'Tornado Warning'
    )
  end
  let(:warning_minor) do
    Skywatch::Nimbus::Models::ConvectiveAlert.new(
      kind: :warning, severity: :minor, event: 'Flash Flood Warning'
    )
  end
  let(:watch) do
    Skywatch::Nimbus::Models::ConvectiveAlert.new(
      kind: :watch, severity: :severe, event: 'Tornado Watch'
    )
  end

  it 'partitions warnings and watches' do
    conv = described_class.new(at: [40.0, -74.0], fetched_at: Time.utc(2026, 4, 25, 18), alerts: [warning, watch])
    expect(conv.warnings).to eq([warning])
    expect(conv.watches).to eq([watch])
  end

  it 'preserves NWS-returned alerts order on .alerts' do
    conv = described_class.new(at: [0, 0], fetched_at: Time.now.utc, alerts: [watch, warning])
    expect(conv.alerts).to eq([watch, warning])
  end

  it 'is active? when any alert exists' do
    expect(described_class.new(at: [0, 0], fetched_at: Time.now.utc, alerts: [warning]).active?).to be true
    expect(described_class.new(at: [0, 0], fetched_at: Time.now.utc, alerts: []).active?).to be false
  end

  it 'returns the highest severity across alerts' do
    conv = described_class.new(at: [0, 0], fetched_at: Time.now.utc, alerts: [warning_minor, warning])
    expect(conv.max_severity).to eq(:extreme)
  end

  it 'returns nil max_severity when empty' do
    conv = described_class.new(at: [0, 0], fetched_at: Time.now.utc, alerts: [])
    expect(conv.max_severity).to be_nil
  end

  it 'serializes to a partitioned hash' do
    conv = described_class.new(
      at: [40.688, -74.174],
      fetched_at: Time.utc(2026, 4, 25, 18, 30),
      alerts: [warning, watch]
    )
    hash = conv.to_h

    expect(hash[:at]).to eq([40.688, -74.174])
    expect(hash[:fetched_at]).to eq('2026-04-25T18:30:00Z')
    expect(hash[:warnings]).to be_an(Array)
    expect(hash[:warnings].first[:event]).to eq('Tornado Warning')
    expect(hash[:watches].first[:event]).to eq('Tornado Watch')
  end
end
