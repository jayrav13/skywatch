# frozen_string_literal: true

RSpec.describe Briefer::Models::Position do
  subject(:position) { described_class.new(lat: 40.8764, lon: -74.2828) }

  it "stores latitude" do
    expect(position.lat).to eq(40.8764)
  end

  it "stores longitude" do
    expect(position.lon).to eq(-74.2828)
  end

  it "is immutable" do
    expect(position).to be_frozen
  end
end
