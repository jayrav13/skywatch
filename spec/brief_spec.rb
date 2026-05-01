# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Skywatch, '.brief' do
  it 'composes a Brief for an airport' do
    composer = instance_double(Skywatch::Brief::Analysis::Composer)
    brief = instance_double(Skywatch::Brief::Models::Brief)
    expect(Skywatch::Brief::Analysis::Composer).to receive(:new).and_return(composer)
    expect(composer).to receive(:compose).with(airport: 'KCDW').and_return(brief)

    expect(described_class.brief(airport: 'KCDW')).to be(brief)
  end
end
