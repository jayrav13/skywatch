# frozen_string_literal: true

RSpec.describe Skywatch::Nimbus::Models::StormReport do
  let(:attrs) do
    {
      time: Time.utc(2026, 4, 19, 18, 42),
      type: :tornado,
      magnitude: nil,
      magnitude_raw: 'EF2',
      location: 'NEWARK',
      county: 'ESSEX',
      state: 'NJ',
      latitude: 40.73,
      longitude: -74.17,
      comments: 'Brief path damage'
    }
  end

  describe '#initialize' do
    it 'stores every attribute' do
      r = described_class.new(**attrs)
      expect(r.time).to eq(Time.utc(2026, 4, 19, 18, 42))
      expect(r.type).to eq(:tornado)
      expect(r.magnitude).to be_nil
      expect(r.magnitude_raw).to eq('EF2')
      expect(r.location).to eq('NEWARK')
      expect(r.county).to eq('ESSEX')
      expect(r.state).to eq('NJ')
      expect(r.latitude).to eq(40.73)
      expect(r.longitude).to eq(-74.17)
      expect(r.comments).to eq('Brief path damage')
    end
  end

  describe '.from_spc_row' do
    let(:report_date) { Date.new(2026, 4, 19) }

    it 'parses a tornado row (F_Scale column → magnitude nil, magnitude_raw passthrough)' do
      row = %w[1842 EF2 NEWARK ESSEX NJ 40.73 -74.17] + ['Brief path damage']
      r = described_class.from_spc_row(row, type: :tornado, report_date: report_date)
      expect(r.type).to eq(:tornado)
      expect(r.time).to eq(Time.utc(2026, 4, 19, 18, 42))
      expect(r.magnitude).to be_nil
      expect(r.magnitude_raw).to eq('EF2')
      expect(r.location).to eq('NEWARK')
      expect(r.county).to eq('ESSEX')
      expect(r.state).to eq('NJ')
      expect(r.latitude).to eq(40.73)
      expect(r.longitude).to eq(-74.17)
      expect(r.comments).to eq('Brief path damage')
    end

    it 'parses a wind row (Speed column → magnitude mph Float, raw preserved)' do
      row = %w[1910 65 JERSEY\ CITY HUDSON NJ 40.72 -74.05] + ['Downed trees']
      r = described_class.from_spc_row(row, type: :wind, report_date: report_date)
      expect(r.type).to eq(:wind)
      expect(r.magnitude).to eq(65.0)
      expect(r.magnitude_raw).to eq('65')
    end

    it 'parses a hail row (Size column → inches Float, raw preserved)' do
      row = %w[2015 175 MANHATTAN NEW\ YORK NY 40.78 -73.97] + ['1.75 inch hail']
      r = described_class.from_spc_row(row, type: :hail, report_date: report_date)
      expect(r.type).to eq(:hail)
      expect(r.magnitude).to eq(1.75)
      expect(r.magnitude_raw).to eq('175')
    end

    it 'preserves magnitude_raw when Speed is unparseable (magnitude nil)' do
      row = ['1910', 'EG 70', 'JERSEY CITY', 'HUDSON', 'NJ', '40.72', '-74.05', 'Estimated gust']
      r = described_class.from_spc_row(row, type: :wind, report_date: report_date)
      expect(r.magnitude).to be_nil
      expect(r.magnitude_raw).to eq('EG 70')
    end

    it 'preserves magnitude_raw when Size is unparseable (magnitude nil)' do
      row = ['2015', 'UNK', 'MANHATTAN', 'NEW YORK', 'NY', '40.78', '-73.97', 'Size unknown']
      r = described_class.from_spc_row(row, type: :hail, report_date: report_date)
      expect(r.magnitude).to be_nil
      expect(r.magnitude_raw).to eq('UNK')
    end
  end

  describe '#wind_kt' do
    let(:report_date) { Date.new(2026, 4, 19) }

    it 'converts mph to knots for wind reports' do
      row = %w[1910 65 JERSEY\ CITY HUDSON NJ 40.72 -74.05] + ['Downed trees']
      r = described_class.from_spc_row(row, type: :wind, report_date: report_date)
      expect(r.wind_kt).to be_within(0.01).of(56.48) # 65 * 0.868976
    end

    it 'is nil when magnitude is nil (unparseable wind)' do
      row = ['1910', 'EG 70', 'JERSEY CITY', 'HUDSON', 'NJ', '40.72', '-74.05', 'Estimated gust']
      r = described_class.from_spc_row(row, type: :wind, report_date: report_date)
      expect(r.wind_kt).to be_nil
    end

    it 'is nil for non-wind report types' do
      r = described_class.new(**attrs) # tornado
      expect(r.wind_kt).to be_nil
    end
  end

  describe '#to_h and #to_json' do
    it 'to_h includes all serializable attributes with ISO-8601 time' do
      r = described_class.new(**attrs)
      hash = r.to_h
      expect(hash[:time]).to eq('2026-04-19T18:42:00Z')
      expect(hash[:type]).to eq(:tornado)
      expect(hash[:magnitude]).to be_nil
      expect(hash[:magnitude_raw]).to eq('EF2')
      expect(hash[:latitude]).to eq(40.73)
    end

    it 'to_json matches the JSON encoding of to_h' do
      r = described_class.new(**attrs)
      expect(JSON.parse(r.to_json)).to eq(JSON.parse(r.to_h.to_json))
    end
  end
end
