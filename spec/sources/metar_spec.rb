# frozen_string_literal: true

RSpec.describe Briefer::Sources::Metar do
  subject(:source) { described_class.new(client: Briefer.client) }

  let(:kcdw_response) { [JSON.parse(File.read("spec/fixtures/metars/kcdw.json"))] }
  let(:multi_response) do
    [
      JSON.parse(File.read("spec/fixtures/metars/kcdw.json")),
      JSON.parse(File.read("spec/fixtures/metars/kewr_gusty.json"))
    ]
  end

  describe "#fetch" do
    it "fetches a single station METAR" do
      stub_request(:get, "https://aviationweather.gov/api/data/metar")
        .with(query: { ids: "KCDW", format: "json" })
        .to_return(status: 200, body: kcdw_response.to_json, headers: { "Content-Type" => "application/json" })

      metars = source.fetch("KCDW")
      expect(metars.size).to eq(1)
      expect(metars.first).to be_a(Briefer::Models::Metar)
      expect(metars.first.station_id).to eq("KCDW")
    end

    it "fetches multiple stations in a single request" do
      stub_request(:get, "https://aviationweather.gov/api/data/metar")
        .with(query: { ids: "KCDW,KEWR", format: "json" })
        .to_return(status: 200, body: multi_response.to_json, headers: { "Content-Type" => "application/json" })

      metars = source.fetch("KCDW", "KEWR")
      expect(metars.size).to eq(2)
      expect(metars.map(&:station_id)).to contain_exactly("KCDW", "KEWR")
    end

    it "returns empty array when API returns empty array" do
      stub_request(:get, "https://aviationweather.gov/api/data/metar")
        .with(query: { ids: "KXYZ", format: "json" })
        .to_return(status: 200, body: "[]", headers: { "Content-Type" => "application/json" })

      metars = source.fetch("KXYZ")
      expect(metars).to eq([])
    end

    it "raises ApiError on HTTP failure" do
      stub_request(:get, "https://aviationweather.gov/api/data/metar")
        .with(query: { ids: "KCDW", format: "json" })
        .to_return(status: 500, body: "Server Error")

      expect { source.fetch("KCDW") }.to raise_error(Briefer::ApiError)
    end

    it "upcases station IDs" do
      stub_request(:get, "https://aviationweather.gov/api/data/metar")
        .with(query: { ids: "KCDW", format: "json" })
        .to_return(status: 200, body: kcdw_response.to_json, headers: { "Content-Type" => "application/json" })

      metars = source.fetch("kcdw")
      expect(metars.first.station_id).to eq("KCDW")
    end
  end
end
