# frozen_string_literal: true

RSpec.describe Briefer::Client::Http do
  subject(:client) { described_class.new }

  describe "#connection" do
    it "sets the base URL to aviationweather.gov" do
      expect(client.connection.url_prefix.to_s).to eq("https://aviationweather.gov/")
    end

    it "sets a custom User-Agent header" do
      user_agent = client.connection.headers["User-Agent"]
      expect(user_agent).to match(%r{Briefer/\d+\.\d+\.\d+ \(ruby; github\.com/jay/briefer\)})
    end

    it "configures open timeout" do
      expect(client.connection.options.open_timeout).to eq(10)
    end

    it "configures read timeout" do
      expect(client.connection.options.timeout).to eq(10)
    end
  end

  describe "#get" do
    it "makes a GET request and returns parsed JSON" do
      stub_request(:get, "https://aviationweather.gov/api/data/metar?ids=KCDW&format=json")
        .to_return(status: 200, body: '[{"icaoId":"KCDW"}]', headers: { "Content-Type" => "application/json" })

      response = client.get("/api/data/metar", ids: "KCDW", format: "json")
      expect(response).to eq([{ "icaoId" => "KCDW" }])
    end

    it "raises ConnectionError on network failure" do
      stub_request(:get, "https://aviationweather.gov/api/data/metar")
        .to_raise(Faraday::ConnectionFailed.new("connection refused"))

      expect { client.get("/api/data/metar") }.to raise_error(Briefer::ConnectionError)
    end

    it "raises ApiError on non-200 response" do
      stub_request(:get, "https://aviationweather.gov/api/data/metar")
        .to_return(status: 500, body: "Internal Server Error")

      expect { client.get("/api/data/metar") }.to raise_error(Briefer::ApiError)
    end
  end
end
