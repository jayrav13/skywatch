# frozen_string_literal: true

RSpec.describe Skywatch::Briefer::Models::Afd do
  let(:data) { JSON.parse(File.read('spec/fixtures/afd/okx_product.json')) }

  describe '.from_nws' do
    subject(:afd) { described_class.from_nws(data) }

    it 'parses the wfo' do
      expect(afd.wfo).to eq('OKX')
    end

    it 'parses the product_name' do
      expect(afd.product_name).to eq('Area Forecast Discussion')
    end

    it 'parses issued_at as UTC Time' do
      expect(afd.issued_at).to eq(Time.utc(2026, 4, 14, 7, 22, 0))
    end

    it 'parses the text' do
      expect(afd.text).to include('Area Forecast Discussion')
      expect(afd.text).to include('National Weather Service New York NY')
    end
  end

  describe '#to_h' do
    subject(:afd) { described_class.from_nws(data) }

    it 'returns a hash with key fields' do
      hash = afd.to_h
      expect(hash[:wfo]).to eq('OKX')
      expect(hash[:product_name]).to eq('Area Forecast Discussion')
      expect(hash[:issued_at]).to eq('2026-04-14T07:22:00Z')
      expect(hash[:text]).to include('Area Forecast Discussion')
    end
  end

  describe '#to_json' do
    subject(:afd) { described_class.from_nws(data) }

    it 'returns valid JSON' do
      parsed = JSON.parse(afd.to_json)
      expect(parsed['wfo']).to eq('OKX')
    end
  end
end
