# frozen_string_literal: true

RSpec.describe Skywatch::Nimbus::Models::Outlook do
  let(:attrs) do
    {
      day: 1,
      label: 'SLGT',
      valid_from: Time.utc(2026, 4, 19, 12),
      valid_to: Time.utc(2026, 4, 20, 12),
      issued_at: Time.utc(2026, 4, 19, 12),
      forecaster: 'GUYER',
      geometry: nil
    }
  end

  describe '#initialize' do
    it 'stores day, label, times, forecaster, geometry' do
      outlook = described_class.new(**attrs)
      expect(outlook.day).to eq(1)
      expect(outlook.label).to eq('SLGT')
      expect(outlook.valid_from).to eq(Time.utc(2026, 4, 19, 12))
      expect(outlook.valid_to).to eq(Time.utc(2026, 4, 20, 12))
      expect(outlook.issued_at).to eq(Time.utc(2026, 4, 19, 12))
      expect(outlook.forecaster).to eq('GUYER')
    end
  end

  describe 'risk classification' do
    {
      'TSTM' => [:general_thunder, 1, 'General Thunderstorms'],
      'MRGL' => [:marginal,        2, 'Marginal Risk'],
      'SLGT' => [:slight,          3, 'Slight Risk'],
      'ENH'  => [:enhanced,        4, 'Enhanced Risk'],
      'MDT'  => [:moderate,        5, 'Moderate Risk'],
      'HIGH' => [:high,            6, 'High Risk']
    }.each do |label, (level, score, description)|
      it "maps #{label} → #{level} / #{score} / #{description.inspect}" do
        outlook = described_class.new(**attrs.merge(label: label))
        expect(outlook.risk_level).to eq(level)
        expect(outlook.risk_score).to eq(score)
        expect(outlook.description).to eq(description)
      end
    end

    it 'raises KeyError for an unknown LABEL' do
      outlook = described_class.new(**attrs.merge(label: 'XYZ'))
      expect { outlook.risk_level }.to raise_error(KeyError)
    end
  end
end
