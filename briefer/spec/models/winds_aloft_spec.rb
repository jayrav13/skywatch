# frozen_string_literal: true

RSpec.describe Briefer::Models::WindsAloft do
  describe ".decode" do
    it "decodes standard wind: 2835+06 at 6000" do
      wa = described_class.decode(station_id: "JFK", altitude_ft: 6000, encoded: "2835+06")
      expect(wa.wind_direction_deg).to eq(280)
      expect(wa.wind_speed_kt).to eq(35)
      expect(wa.temperature_c).to eq(6)
      expect(wa).not_to be_light_and_variable
    end

    it "decodes negative temp: 2510-09 at 9000" do
      wa = described_class.decode(station_id: "JFK", altitude_ft: 9000, encoded: "2510-09")
      expect(wa.wind_direction_deg).to eq(250)
      expect(wa.wind_speed_kt).to eq(10)
      expect(wa.temperature_c).to eq(-9)
    end

    it "decodes light and variable: 9900+05" do
      wa = described_class.decode(station_id: "JFK", altitude_ft: 3000, encoded: "9900+05")
      expect(wa).to be_light_and_variable
      expect(wa.wind_direction_deg).to be_nil
      expect(wa.wind_speed_kt).to be_nil
      expect(wa.temperature_c).to eq(5)
    end

    it "decodes high speed (>100kt): 762849 at 30000" do
      wa = described_class.decode(station_id: "JFK", altitude_ft: 30_000, encoded: "762849")
      expect(wa.wind_direction_deg).to eq(260)
      expect(wa.wind_speed_kt).to eq(128)
      expect(wa.temperature_c).to eq(-49)
    end

    it "decodes wind-only (no temp): 2124 at 3000" do
      wa = described_class.decode(station_id: "ABR", altitude_ft: 3000, encoded: "2124")
      expect(wa.wind_direction_deg).to eq(210)
      expect(wa.wind_speed_kt).to eq(24)
      expect(wa.temperature_c).to be_nil
    end

    it "returns nil for nil encoded string" do
      wa = described_class.decode(station_id: "ABQ", altitude_ft: 3000, encoded: nil)
      expect(wa).to be_nil
    end
  end

  describe "#to_h" do
    it "returns a hash with all fields" do
      wa = described_class.decode(station_id: "JFK", altitude_ft: 6000, encoded: "2835+06")
      hash = wa.to_h
      expect(hash[:station_id]).to eq("JFK")
      expect(hash[:altitude_ft]).to eq(6000)
      expect(hash[:wind_direction_deg]).to eq(280)
    end
  end
end
