# frozen_string_literal: true

RSpec.describe Briefer::Sources::Taf do
  subject(:source) { described_class.new(client: Briefer.client) }

  let(:kack_response) { [JSON.parse(File.read("spec/fixtures/tafs/kack.json"))] }

  describe "#fetch" do
    it "fetches and returns Taf models" do
      stub_request(:get, "https://aviationweather.gov/api/data/taf")
        .with(query: { ids: "KACK", format: "json" })
        .to_return(status: 200, body: kack_response.to_json, headers: { "Content-Type" => "application/json" })

      tafs = source.fetch("KACK")
      expect(tafs.size).to eq(1)
      expect(tafs.first).to be_a(Briefer::Models::Taf)
      expect(tafs.first.station_id).to eq("KACK")
      expect(tafs.first.forecast_groups.size).to eq(3)
    end

    it "upcases station IDs" do
      stub_request(:get, "https://aviationweather.gov/api/data/taf")
        .with(query: { ids: "KACK", format: "json" })
        .to_return(status: 200, body: kack_response.to_json, headers: { "Content-Type" => "application/json" })

      tafs = source.fetch("kack")
      expect(tafs.first.station_id).to eq("KACK")
    end
  end
end
