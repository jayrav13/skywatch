# frozen_string_literal: true

RSpec.describe Skywatch::Briefer::Sources::Pirep do
  subject(:source) { described_class.new(client: Skywatch.client) }

  let(:pirep_response) do
    [
      JSON.parse(File.read('spec/fixtures/pireps/icing.json')),
      JSON.parse(File.read('spec/fixtures/pireps/turbulence.json'))
    ]
  end

  describe '#fetch' do
    it 'fetches PIREPs near a station' do
      stub_request(:get, 'https://aviationweather.gov/api/data/pirep')
        .with(query: { id: 'KCDW', dist: '100', format: 'json' })
        .to_return(status: 200, body: pirep_response.to_json, headers: { 'Content-Type' => 'application/json' })

      pireps = source.fetch('KCDW', radius_nm: 100)
      expect(pireps.size).to eq(2)
      expect(pireps).to all(be_a(Skywatch::Briefer::Models::Pirep))
    end

    it 'defaults to 100nm radius' do
      stub_request(:get, 'https://aviationweather.gov/api/data/pirep')
        .with(query: { id: 'KJFK', dist: '100', format: 'json' })
        .to_return(status: 200, body: '[]', headers: { 'Content-Type' => 'application/json' })

      pireps = source.fetch('KJFK')
      expect(pireps).to eq([])
    end
  end
end
