# frozen_string_literal: true

RSpec.describe Skywatch::Briefer::Models::TafGroup do
  let(:taf_data) { JSON.parse(File.read('spec/fixtures/tafs/kack.json')) }

  describe '.from_awc' do
    context 'with initial forecast group' do
      subject(:group) { described_class.from_awc(taf_data['fcsts'][0]) }

      it 'parses time_from as UTC' do
        expect(group.time_from).to be_a(Time)
        expect(group.time_from.utc?).to be(true)
      end

      it 'parses time_to' do
        expect(group.time_to).to be_a(Time)
      end

      it 'sets change_type to :initial for nil fcstChange' do
        expect(group.change_type).to eq(:initial)
      end

      it 'parses wind' do
        expect(group.wind_direction_deg).to eq(20)
        expect(group.wind_speed_kt).to eq(14)
        expect(group.wind_gust_kt).to be_nil
      end

      it 'parses visibility' do
        expect(group.visibility_sm).to eq(6.0)
      end

      it 'parses sky condition' do
        expect(group.sky_condition).to eq([{ cover: :bkn, base_ft: 7000 }])
      end

      it 'computes ceiling' do
        expect(group.ceiling_ft).to eq(7000)
      end

      it 'computes flight category' do
        expect(group.flight_category).to eq(:vfr)
      end
    end

    context 'with FM group (gusty, OVC)' do
      subject(:group) { described_class.from_awc(taf_data['fcsts'][1]) }

      it 'sets change_type to :fm' do
        expect(group.change_type).to eq(:fm)
      end

      it 'parses gusts' do
        expect(group.wind_gust_kt).to eq(23)
      end

      it 'computes ceiling from OVC' do
        expect(group.ceiling_ft).to eq(5000)
      end
    end

    context 'with FEW-only group (no ceiling)' do
      subject(:group) { described_class.from_awc(taf_data['fcsts'][2]) }

      it 'returns nil ceiling for FEW' do
        expect(group.ceiling_ft).to be_nil
      end

      it 'classifies as VFR' do
        expect(group.flight_category).to eq(:vfr)
      end
    end
  end

  describe '#to_h' do
    subject(:group) { described_class.from_awc(taf_data['fcsts'][0]) }

    it 'returns a hash with all fields' do
      hash = group.to_h
      expect(hash[:change_type]).to eq(:initial)
      expect(hash[:wind_speed_kt]).to eq(14)
      expect(hash[:flight_category]).to eq(:vfr)
    end
  end
end
