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
end
