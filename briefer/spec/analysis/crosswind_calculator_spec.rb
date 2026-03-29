# frozen_string_literal: true

RSpec.describe Briefer::Analysis::CrosswindCalculator do
  describe ".calculate" do
    it "calculates crosswind for 90-degree cross" do
      result = described_class.calculate(wind_direction_deg: 280, wind_speed_kt: 15, runway_heading: 190)
      expect(result[:crosswind_kt]).to be_within(0.1).of(15.0)
      expect(result[:headwind_kt]).to be_within(0.1).of(0.0)
    end

    it "calculates headwind for direct headwind" do
      result = described_class.calculate(wind_direction_deg: 280, wind_speed_kt: 15, runway_heading: 280)
      expect(result[:crosswind_kt]).to be_within(0.1).of(0.0)
      expect(result[:headwind_kt]).to be_within(0.1).of(15.0)
    end

    it "calculates for angled wind" do
      result = described_class.calculate(wind_direction_deg: 330, wind_speed_kt: 15, runway_heading: 280)
      # 50 degree angle: crosswind = 15 * sin(50) = 11.5, headwind = 15 * cos(50) = 9.6
      expect(result[:crosswind_kt]).to be_within(0.5).of(11.5)
      expect(result[:headwind_kt]).to be_within(0.5).of(9.6)
    end

    it "returns zeros for calm winds" do
      result = described_class.calculate(wind_direction_deg: 0, wind_speed_kt: 0, runway_heading: 280)
      expect(result[:crosswind_kt]).to eq(0.0)
      expect(result[:headwind_kt]).to eq(0.0)
    end

    it "handles tailwind (negative headwind)" do
      result = described_class.calculate(wind_direction_deg: 100, wind_speed_kt: 10, runway_heading: 280)
      expect(result[:headwind_kt]).to be < 0
    end

    it "handles wind direction wrapping around 360" do
      result = described_class.calculate(wind_direction_deg: 350, wind_speed_kt: 10, runway_heading: 10)
      # 20 degree angle
      expect(result[:crosswind_kt]).to be_within(0.5).of(3.4)
      expect(result[:headwind_kt]).to be_within(0.5).of(9.4)
    end
  end
end
