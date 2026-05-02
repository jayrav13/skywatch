# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Skywatch, '.brief' do
  let(:composer) { instance_double(Skywatch::Brief::Analysis::Composer) }
  let(:brief) { instance_double(Skywatch::Brief::Models::Brief) }

  before { allow(Skywatch::Brief::Analysis::Composer).to receive(:new).and_return(composer) }

  it 'composes a Brief for an airport' do
    expect(composer).to receive(:compose)
      .with(airport: 'KCDW', at: nil, departing_at: nil, from: nil, to: nil).and_return(brief)
    expect(described_class.brief(airport: 'KCDW')).to be(brief)
  end

  it 'composes a Brief for a coordinate pair' do
    expect(composer).to receive(:compose)
      .with(airport: nil, at: [40.688, -74.174], departing_at: nil, from: nil, to: nil).and_return(brief)
    expect(described_class.brief(at: [40.688, -74.174])).to be(brief)
  end

  it 'passes departing_at through to composer' do
    etd = Time.utc(2026, 5, 1, 16, 0, 0)
    expect(composer).to receive(:compose)
      .with(airport: 'KCDW', at: nil, departing_at: etd, from: nil, to: nil).and_return(brief)
    expect(described_class.brief(airport: 'KCDW', departing_at: etd)).to be(brief)
  end

  it 'passes from: and to: through to composer for a route brief' do
    expect(composer).to receive(:compose)
      .with(airport: nil, at: nil, departing_at: nil, from: 'KCDW', to: 'KACY').and_return(brief)
    expect(described_class.brief(from: 'KCDW', to: 'KACY')).to be(brief)
  end
end
