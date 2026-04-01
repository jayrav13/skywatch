# frozen_string_literal: true

RSpec.describe Skywatch::Briefer::Models::Sigmet do
  let(:data) { JSON.parse(File.read('spec/fixtures/sigmets/convective.json')) }

  describe '.from_awc' do
    subject(:sigmet) { described_class.from_awc(data) }

    it 'parses identification fields' do
      expect(sigmet.series_id).to eq('3E')
      expect(sigmet.issuing_center).to eq('KKCI')
      expect(sigmet.sigmet_type).to eq(:sigmet)
      expect(sigmet.hazard).to eq('CONVECTIVE')
      expect(sigmet.severity).to eq(5)
    end

    it 'parses time fields' do
      expect(sigmet.valid_from).to be_a(Time)
      expect(sigmet.valid_from.utc?).to be(true)
      expect(sigmet.valid_to).to be_a(Time)
    end

    it 'parses altitude fields' do
      expect(sigmet.altitude_hi_ft).to eq(32_000)
      expect(sigmet.altitude_low_ft).to be_nil
    end

    it 'parses movement' do
      expect(sigmet.movement_dir_deg).to eq(10)
      expect(sigmet.movement_speed_kt).to eq(15)
    end

    it 'parses coords as Position array' do
      expect(sigmet.coords).to all(be_a(Skywatch::Shared::Position))
      expect(sigmet.coords.size).to eq(5)
      expect(sigmet.coords.first.lat).to eq(28.145)
    end

    it 'parses raw text' do
      expect(sigmet.raw).to include('CONVECTIVE SIGMET 3E')
    end
  end

  describe '#polygon' do
    subject(:sigmet) { described_class.from_awc(data) }

    it 'returns an RGeo polygon' do
      expect(sigmet.polygon).to be_a(RGeo::Geographic::SphericalPolygonImpl)
    end
  end

  describe '#to_h' do
    subject(:sigmet) { described_class.from_awc(data) }

    it 'returns a hash with key fields' do
      hash = sigmet.to_h
      expect(hash[:series_id]).to eq('3E')
      expect(hash[:hazard]).to eq('CONVECTIVE')
      expect(hash[:coords]).to be_an(Array)
    end
  end
end
