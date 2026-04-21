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
end
