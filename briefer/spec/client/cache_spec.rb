# frozen_string_literal: true

RSpec.describe Briefer::Client::Cache do
  subject(:cache) { described_class.new(client: http_client) }

  let(:http_client) { Briefer::Client::Http.new }

  before do
    stub_request(:get, "https://aviationweather.gov/api/data/metar?ids=KCDW&format=json")
      .to_return(status: 200, body: '[{"icaoId":"KCDW"}]', headers: { "Content-Type" => "application/json" })
  end

  describe "#get" do
    it "delegates to the underlying client" do
      result = cache.get("/api/data/metar", { ids: "KCDW", format: "json" }, ttl: 300)
      expect(result).to eq([{ "icaoId" => "KCDW" }])
    end

    it "returns cached response on second call" do
      cache.get("/api/data/metar", { ids: "KCDW", format: "json" }, ttl: 300)
      cache.get("/api/data/metar", { ids: "KCDW", format: "json" }, ttl: 300)
      expect(WebMock).to have_requested(:get, "https://aviationweather.gov/api/data/metar?ids=KCDW&format=json").once
    end

    it "fetches again after TTL expires" do
      cache.get("/api/data/metar", { ids: "KCDW", format: "json" }, ttl: 0)
      sleep 0.01
      cache.get("/api/data/metar", { ids: "KCDW", format: "json" }, ttl: 0)
      expect(WebMock).to have_requested(:get, "https://aviationweather.gov/api/data/metar?ids=KCDW&format=json").twice
    end

    it "uses different cache keys for different params" do
      stub_request(:get, "https://aviationweather.gov/api/data/metar?ids=KTEB&format=json")
        .to_return(status: 200, body: '[{"icaoId":"KTEB"}]', headers: { "Content-Type" => "application/json" })
      result1 = cache.get("/api/data/metar", { ids: "KCDW", format: "json" }, ttl: 300)
      result2 = cache.get("/api/data/metar", { ids: "KTEB", format: "json" }, ttl: 300)
      expect(result1.first["icaoId"]).to eq("KCDW")
      expect(result2.first["icaoId"]).to eq("KTEB")
    end
  end

  describe "#clear" do
    it "empties the cache" do
      cache.get("/api/data/metar", { ids: "KCDW", format: "json" }, ttl: 300)
      cache.clear
      cache.get("/api/data/metar", { ids: "KCDW", format: "json" }, ttl: 300)
      expect(WebMock).to have_requested(:get, "https://aviationweather.gov/api/data/metar?ids=KCDW&format=json").twice
    end
  end

  describe "#size" do
    it "returns the number of cached entries" do
      expect(cache.size).to eq(0)
      cache.get("/api/data/metar", { ids: "KCDW", format: "json" }, ttl: 300)
      expect(cache.size).to eq(1)
    end
  end
end
