# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Skywatch, '.brief' do
  let(:composer) { instance_double(Skywatch::Brief::Analysis::Composer) }
  let(:brief) { instance_double(Skywatch::Brief::Models::Brief) }

  before { allow(Skywatch::Brief::Analysis::Composer).to receive(:new).and_return(composer) }

  it 'composes a Brief for an airport' do
    expect(composer).to receive(:compose).with(airport: 'KCDW', at: nil).and_return(brief)
    expect(described_class.brief(airport: 'KCDW')).to be(brief)
  end

  it 'composes a Brief for a coordinate pair' do
    expect(composer).to receive(:compose).with(airport: nil, at: [40.688, -74.174]).and_return(brief)
    expect(described_class.brief(at: [40.688, -74.174])).to be(brief)
  end
end
