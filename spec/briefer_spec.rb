# frozen_string_literal: true

RSpec.describe Briefer do
  it "has a version number" do
    expect(Briefer::VERSION).not_to be_nil
  end

  describe ".metar" do
    let(:kcdw_data) { [JSON.parse(File.read("spec/fixtures/metars/kcdw.json"))] }

    before do
      stub_request(:get, "https://aviationweather.gov/api/data/metar")
        .with(query: { ids: "KCDW", format: "json" })
        .to_return(status: 200, body: kcdw_data.to_json, headers: { "Content-Type" => "application/json" })
    end

    it "returns an array of Metar models" do
      metars = described_class.metar("KCDW")
      expect(metars).to be_an(Array)
      expect(metars.first).to be_a(Briefer::Models::Metar)
      expect(metars.first.station_id).to eq("KCDW")
      expect(metars.first.flight_category).to eq(:vfr)
    end
  end

  describe ".client" do
    it "returns a lazy-initialized HTTP client" do
      expect(described_class.client).to be_a(Briefer::Client::Cache)
    end

    it "returns the same instance on repeated calls" do
      expect(described_class.client).to be(described_class.client)
    end
  end

  describe ".reset!" do
    it "clears the cached client" do
      first_client = described_class.client
      described_class.reset!
      expect(described_class.client).not_to be(first_client)
    end
  end
end
