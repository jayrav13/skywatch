# frozen_string_literal: true

RSpec.describe Skywatch::Shared::Http do
  subject(:client) { described_class.new }

  describe '#connection' do
    it 'sets the base URL to aviationweather.gov by default' do
      expect(client.connection.url_prefix.to_s).to eq('https://aviationweather.gov/')
    end

    it 'accepts a custom base URL' do
      custom = described_class.new(base_url: 'https://opensky-network.org')
      expect(custom.connection.url_prefix.to_s).to eq('https://opensky-network.org/')
    end

    it 'sets a custom User-Agent header' do
      user_agent = client.connection.headers['User-Agent']
      expect(user_agent).to match(%r{Skywatch/\d+\.\d+\.\d+ \(ruby; github\.com/jayrav13/skywatch\)})
    end
  end

  describe '#get' do
    it 'makes a GET request and returns parsed JSON' do
      stub_request(:get, 'https://aviationweather.gov/api/data/metar')
        .with(query: { ids: 'KCDW', format: 'json' })
        .to_return(status: 200, body: '[{"icaoId":"KCDW"}]',
                   headers: { 'Content-Type' => 'application/json' })

      response = client.get('/api/data/metar', { ids: 'KCDW', format: 'json' })
      expect(response).to eq([{ 'icaoId' => 'KCDW' }])
    end

    it 'raises ConnectionError on network failure' do
      stub_request(:get, 'https://aviationweather.gov/api/data/metar')
        .to_raise(Faraday::ConnectionFailed.new('connection refused'))

      expect { client.get('/api/data/metar') }.to raise_error(Skywatch::ConnectionError)
    end

    it 'raises ApiError on non-200 response' do
      stub_request(:get, 'https://aviationweather.gov/api/data/metar')
        .to_return(status: 500, body: 'Internal Server Error')

      expect { client.get('/api/data/metar') }.to raise_error(Skywatch::ApiError)
    end
  end

  describe '#get_raw' do
    it 'returns response body as string' do
      stub_request(:get, 'https://aviationweather.gov/api/data/fcstdisc')
        .with(query: { cwa: 'KBOX' })
        .to_return(status: 200, body: 'Raw text', headers: { 'Content-Type' => 'text/plain' })

      result = client.get_raw('/api/data/fcstdisc', { cwa: 'KBOX' })
      expect(result).to eq('Raw text')
    end
  end
end
