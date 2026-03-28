# frozen_string_literal: true

RSpec.describe Briefer::Models::Taf do
  let(:taf_data) { JSON.parse(File.read("spec/fixtures/tafs/kack.json")) }

  describe ".from_awc" do
    subject(:taf) { described_class.from_awc(taf_data) }

    it "parses station_id" do
      expect(taf.station_id).to eq("KACK")
    end

    it "parses raw TAF" do
      expect(taf.raw).to start_with("TAF KACK")
    end

    it "parses issued_at" do
      expect(taf.issued_at).to be_a(Time)
    end

    it "parses valid_from and valid_to" do
      expect(taf.valid_from).to be_a(Time)
      expect(taf.valid_to).to be_a(Time)
      expect(taf.valid_to).to be > taf.valid_from
    end

    it "parses station info" do
      expect(taf.station_name).to eq("Nantucket Mem Arpt")
      expect(taf.latitude).to eq(41.25407)
    end

    it "builds position" do
      expect(taf.position).to eq(Briefer::Models::Position.new(lat: 41.25407, lon: -70.05892))
    end

    it "parses forecast groups" do
      expect(taf.forecast_groups.size).to eq(3)
      expect(taf.forecast_groups).to all(be_a(Briefer::Models::TafGroup))
    end

    it "has correct change types in order" do
      types = taf.forecast_groups.map(&:change_type)
      expect(types).to eq(%i[initial fm fm])
    end
  end

  describe "#group_at" do
    subject(:taf) { described_class.from_awc(taf_data) }

    it "returns the initial group for a time in the first period" do
      time = taf.valid_from + 60
      group = taf.group_at(time)
      expect(group.change_type).to eq(:initial)
    end

    it "returns the FM group for a time in the second period" do
      time = Time.at(1_774_713_600).utc + 60
      group = taf.group_at(time)
      expect(group.change_type).to eq(:fm)
      expect(group.wind_gust_kt).to eq(23)
    end

    it "returns nil for a time outside the valid period" do
      group = taf.group_at(Time.at(0).utc)
      expect(group).to be_nil
    end
  end

  describe "#to_h" do
    subject(:taf) { described_class.from_awc(taf_data) }

    it "includes station_id and forecast_groups" do
      hash = taf.to_h
      expect(hash[:station_id]).to eq("KACK")
      expect(hash[:forecast_groups]).to be_an(Array)
      expect(hash[:forecast_groups].size).to eq(3)
    end
  end

  describe "#to_json" do
    subject(:taf) { described_class.from_awc(taf_data) }

    it "returns valid JSON" do
      parsed = JSON.parse(taf.to_json)
      expect(parsed["station_id"]).to eq("KACK")
    end
  end
end
