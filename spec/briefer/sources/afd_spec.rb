# frozen_string_literal: true

RSpec.describe Skywatch::Briefer::Sources::Afd do
  subject(:source) { described_class.new }

  let(:products_data) { JSON.parse(File.read('spec/fixtures/afd/okx_products.json')) }
  let(:product_data) { JSON.parse(File.read('spec/fixtures/afd/okx_product.json')) }

  before do
    stub_request(:get, 'https://api.weather.gov/products/types/AFD/locations/OKX')
      .to_return(status: 200, body: products_data.to_json,
                 headers: { 'Content-Type' => 'application/json' })

    stub_request(:get, 'https://api.weather.gov/products/abc12345-0000-0000-0000-000000000001')
      .to_return(status: 200, body: product_data.to_json,
                 headers: { 'Content-Type' => 'application/json' })
  end

  describe '#fetch' do
    it 'returns an Afd model' do
      afd = source.fetch('OKX')
      expect(afd).to be_a(Skywatch::Briefer::Models::Afd)
    end

    it 'sets the wfo' do
      afd = source.fetch('OKX')
      expect(afd.wfo).to eq('OKX')
    end

    it 'parses issued_at correctly' do
      afd = source.fetch('OKX')
      expect(afd.issued_at).to eq(Time.utc(2026, 4, 14, 7, 22, 0))
    end

    it 'includes the product text' do
      afd = source.fetch('OKX')
      expect(afd.text).to include('Area Forecast Discussion')
    end

    it 'raises ApiError on HTTP failure' do
      stub_request(:get, 'https://api.weather.gov/products/types/AFD/locations/OKX')
        .to_return(status: 500, body: 'Server Error')

      expect { source.fetch('OKX') }.to raise_error(Skywatch::ApiError)
    end
  end
end
