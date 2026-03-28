# frozen_string_literal: true

RSpec.describe Briefer::Models::Metar do
  def load_fixture(name)
    JSON.parse(File.read("spec/fixtures/metars/#{name}.json"))
  end

  describe ".from_awc" do
    context "with a standard METAR (KCDW)" do
      subject(:metar) { described_class.from_awc(load_fixture("kcdw")) }

      it "parses station_id" do
        expect(metar.station_id).to eq("KCDW")
      end

      it "parses the raw observation" do
        expect(metar.raw).to start_with("METAR KCDW")
      end

      it "parses observed_at as UTC Time" do
        expect(metar.observed_at).to be_a(Time)
        expect(metar.observed_at.utc?).to be(true)
      end

      it "parses temperature" do
        expect(metar.temperature_c).to eq(3.9)
      end

      it "parses dewpoint" do
        expect(metar.dewpoint_c).to eq(-8.9)
      end

      it "parses wind" do
        expect(metar.wind_direction_deg).to eq(330)
        expect(metar.wind_speed_kt).to eq(3)
        expect(metar.wind_gust_kt).to be_nil
      end

      it "parses visibility as float" do
        expect(metar.visibility_sm).to eq(10.0)
      end

      it "parses altimeter from hPa to inHg" do
        expect(metar.altimeter_inhg).to be_within(0.01).of(30.22)
      end

      it "parses sky condition" do
        expect(metar.sky_condition).to eq([{ cover: :bkn, base_ft: 7000 }])
      end

      it "computes ceiling from BKN layer" do
        expect(metar.ceiling_ft).to eq(7000)
      end

      it "parses station info" do
        expect(metar.station_name).to eq("Caldwell/Essex Cnty, NJ, US")
        expect(metar.elevation_ft).to be_within(1).of(170)
      end

      it "builds a position" do
        expect(metar.position).to eq(Briefer::Models::Position.new(lat: 40.8764, lon: -74.2828))
      end

      it "classifies as VFR" do
        expect(metar.flight_category).to eq(:vfr)
        expect(metar).to be_vfr
      end

      it "computes spread" do
        expect(metar.spread_c).to be_within(0.1).of(12.8)
      end
    end

    context "with gusty winds (KEWR)" do
      subject(:metar) { described_class.from_awc(load_fixture("kewr_gusty")) }

      it "parses gust speed" do
        expect(metar.wind_gust_kt).to eq(21)
      end

      it "finds ceiling from first BKN/OVC layer" do
        expect(metar.ceiling_ft).to eq(6500)
      end
    end

    context "with calm winds" do
      subject(:metar) { described_class.from_awc(load_fixture("calm_winds")) }

      it "parses calm winds as zero" do
        expect(metar.wind_direction_deg).to eq(0)
        expect(metar.wind_speed_kt).to eq(0)
      end
    end

    context "with clear sky" do
      subject(:metar) { described_class.from_awc(load_fixture("clear_sky")) }

      it "returns nil ceiling" do
        expect(metar.ceiling_ft).to be_nil
      end

      it "classifies as VFR" do
        expect(metar.flight_category).to eq(:vfr)
      end
    end
  end

  describe "#to_h" do
    subject(:metar) { described_class.from_awc(load_fixture("kcdw")) }

    it "returns a hash with all fields" do
      hash = metar.to_h
      expect(hash[:station_id]).to eq("KCDW")
      expect(hash[:flight_category]).to eq(:vfr)
      expect(hash[:temperature_c]).to eq(3.9)
    end
  end

  describe "#to_json" do
    subject(:metar) { described_class.from_awc(load_fixture("kcdw")) }

    it "returns valid JSON" do
      parsed = JSON.parse(metar.to_json)
      expect(parsed["station_id"]).to eq("KCDW")
    end
  end
end
