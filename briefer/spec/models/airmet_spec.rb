# frozen_string_literal: true

RSpec.describe Briefer::Models::Airmet do
  let(:data) { JSON.parse(File.read("spec/fixtures/airmets/sierra.json")) }

  describe ".from_awc" do
    subject(:airmet) { described_class.from_awc(data) }

    it "parses identification fields" do # rubocop:disable RSpec/MultipleExpectations
      expect(airmet.tag).to eq("3E")
      expect(airmet.product).to eq(:sierra)
      expect(airmet.hazard).to eq("MT_OBSC")
      expect(airmet.forecast_hour).to eq(6)
    end

    it "converts blank strings to nil" do
      expect(airmet.severity).to be_nil
      expect(airmet.top).to be_nil
      expect(airmet.base).to be_nil
    end

    it "parses due_to" do
      expect(airmet.due_to).to eq("MTNS OBSC BY CLDS/BR")
    end

    it "parses time fields" do
      expect(airmet.valid_at).to be_a(Time)
      expect(airmet.valid_at.utc?).to be(true)
      expect(airmet.issued_at).to be_a(Time)
      expect(airmet.expires_at).to be_a(Time)
    end

    it "parses coords as Position array" do
      expect(airmet.coords).to all(be_a(Briefer::Models::Position))
      expect(airmet.coords.size).to eq(8)
      expect(airmet.coords.first.lat).to be_within(0.01).of(47.62)
    end
  end

  describe "#polygon" do
    subject(:airmet) { described_class.from_awc(data) }

    it "returns an RGeo polygon" do
      expect(airmet.polygon).to be_a(RGeo::Geographic::SphericalPolygonImpl)
    end
  end

  describe "#to_h" do
    subject(:airmet) { described_class.from_awc(data) }

    it "returns a hash with key fields" do
      hash = airmet.to_h
      expect(hash[:tag]).to eq("3E")
      expect(hash[:product]).to eq(:sierra)
      expect(hash[:coords]).to be_an(Array)
    end
  end
end
