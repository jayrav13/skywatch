# frozen_string_literal: true

RSpec.describe Skywatch::Nimbus::Sources::StormReport do
  subject(:source) { described_class.new }

  describe '#fetch default (today.csv)' do
    let(:csv) { File.read('spec/fixtures/spc/sample.csv') }

    before do
      stub_request(:get, 'https://www.spc.noaa.gov/climo/reports/today.csv')
        .to_return(status: 200, body: csv,
                   headers: { 'Content-Type' => 'text/csv' })
    end

    it 'returns StormReport models' do
      result = source.fetch
      expect(result).to all(be_a(Skywatch::Nimbus::Models::StormReport))
    end

    it 'splits the CSV into tornado / wind / hail sections' do
      result = source.fetch
      by_type = result.group_by(&:type).transform_values(&:count)
      expect(by_type).to eq(tornado: 1, wind: 2, hail: 2)
    end

    it 'stamps each report time against today in UTC' do
      today = Date.today
      result = source.fetch
      expect(result.map { |r| r.time.to_date }).to all(eq(today))
      expect(result.first.time).to be_utc
    end

    it 'returns [] when every section is header-only' do
      stub_request(:get, 'https://www.spc.noaa.gov/climo/reports/today.csv')
        .to_return(status: 200,
                   body: File.read('spec/fixtures/spc/today_empty.csv'),
                   headers: { 'Content-Type' => 'text/csv' })
      expect(source.fetch).to eq([])
    end
  end

  describe '#fetch with explicit date' do
    before do
      stub_request(:get, 'https://www.spc.noaa.gov/climo/reports/260415.csv')
        .to_return(status: 200,
                   body: File.read('spec/fixtures/spc/260415.csv'),
                   headers: { 'Content-Type' => 'text/csv' })
    end

    it 'builds the YYMMDD URL and stamps times against that date' do
      date = Date.new(2026, 4, 15)
      result = source.fetch(date: date)
      expect(result).to all(be_a(Skywatch::Nimbus::Models::StormReport))
      result.each { |r| expect(r.time.to_date).to eq(date) } unless result.empty?
    end
  end
end
