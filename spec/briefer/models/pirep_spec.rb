# frozen_string_literal: true

RSpec.describe Skywatch::Briefer::Models::Pirep do
  def load_fixture(name)
    JSON.parse(File.read("spec/fixtures/pireps/#{name}.json"))
  end

  describe ".from_awc" do
    context "with icing PIREP" do
      subject(:pirep) { described_class.from_awc(load_fixture("icing")) }

      it "parses basic fields" do # rubocop:disable RSpec/MultipleExpectations
        expect(pirep.aircraft_type).to eq("C17")
        expect(pirep.flight_level).to eq(70)
        expect(pirep.altitude_ft).to eq(7000)
        expect(pirep.temperature_c).to eq(-10)
        expect(pirep.pirep_type).to eq(:pirep)
      end

      it "parses position" do
        expect(pirep.latitude).to eq(40.0143)
        expect(pirep.longitude).to eq(-73.7172)
        expect(pirep.position).to eq(Skywatch::Shared::Position.new(lat: 40.0143, lon: -73.7172))
      end

      it "parses observed_at" do
        expect(pirep.observed_at).to be_a(Time)
        expect(pirep.observed_at.utc?).to be(true)
      end

      it "parses icing" do
        expect(pirep.icing_intensity).to eq("LGT")
        expect(pirep.icing_type).to eq("RIME")
        expect(pirep.icing_base_ft).to eq(5000)
        expect(pirep.icing_top_ft).to eq(8000)
      end

      it "reports icing present" do
        expect(pirep).to be_icing
        expect(pirep).not_to be_turbulence
      end

      it "parses raw observation" do
        expect(pirep.raw).to include("IC LGT RIME")
      end
    end

    context "with turbulence PIREP" do
      subject(:pirep) { described_class.from_awc(load_fixture("turbulence")) }

      it "parses turbulence" do
        expect(pirep.turbulence_intensity).to eq("MOD")
        expect(pirep.turbulence_base_ft).to eq(12_000)
        expect(pirep.turbulence_top_ft).to eq(15_000)
      end

      it "reports turbulence present" do
        expect(pirep).to be_turbulence
        expect(pirep).not_to be_icing
      end

      it "has no temperature" do
        expect(pirep.temperature_c).to be_nil
      end
    end
  end

  describe "#to_h" do
    subject(:pirep) { described_class.from_awc(load_fixture("icing")) }

    it "returns hash with key fields" do
      hash = pirep.to_h
      expect(hash[:aircraft_type]).to eq("C17")
      expect(hash[:icing_intensity]).to eq("LGT")
      expect(hash[:altitude_ft]).to eq(7000)
    end
  end
end
