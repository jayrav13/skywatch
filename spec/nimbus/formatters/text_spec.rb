# frozen_string_literal: true

RSpec.describe Skywatch::Nimbus::Formatters::Text do
  describe '.format_outlook' do
    let(:feature) { JSON.parse(File.read('spec/fixtures/spc/day1_synthetic.geojson'))['features'].first }
    let(:outlook) { Skywatch::Nimbus::Models::Outlook.from_spc_feature(feature, day: 1) }

    it 'renders day, label, description, validity window, forecaster' do
      line = described_class.format_outlook(outlook)
      expect(line).to include('OUTLOOK DAY 1')
      expect(line).to include('MRGL')
      expect(line).to include('Marginal Risk')
      expect(line).to include('2026-04-19 12:00Z')
      expect(line).to include('2026-04-20 12:00Z')
      expect(line).to include('GUYER')
      expect(line).to end_with("\n")
    end
  end

  describe '.format_storm_report' do
    let(:report_date) { Date.new(2026, 4, 19) }

    def report_for(type, row)
      Skywatch::Nimbus::Models::StormReport.from_spc_row(row, type: type, report_date: report_date)
    end

    it 'renders a tornado' do
      row = %w[1842 EF2 NEWARK ESSEX NJ 40.73 -74.17] + ['Brief path damage']
      line = described_class.format_storm_report(report_for(:tornado, row))
      expect(line).to include('TORNADO EF2')
      expect(line).to include('18:42Z')
      expect(line).to include('NEWARK, ESSEX NJ')
      expect(line).to include('(40.73, -74.17)')
      expect(line).to include('Brief path damage')
    end

    it 'renders wind with mph and kt' do
      row = ['1910', '65', 'JERSEY CITY', 'HUDSON', 'NJ', '40.72', '-74.05'] + ['Downed trees']
      line = described_class.format_storm_report(report_for(:wind, row))
      expect(line).to include('WIND 65mph')
      expect(line).to include('kt ~56')
    end

    it 'renders hail in inches' do
      row = ['2015', '175', 'MANHATTAN', 'NEW YORK', 'NY', '40.78', '-73.97'] + ['1.75 inch hail']
      line = described_class.format_storm_report(report_for(:hail, row))
      expect(line).to include('HAIL 1.75"')
    end

    it 'falls back to magnitude_raw when magnitude is unparseable' do
      row = ['1910', 'EG 70', 'JERSEY CITY', 'HUDSON', 'NJ', '40.72', '-74.05', 'Estimated gust']
      line = described_class.format_storm_report(report_for(:wind, row))
      expect(line).to include('WIND EG 70')
    end
  end

  describe '.format_convection' do
    def alert(**attrs)
      Skywatch::Nimbus::Models::ConvectiveAlert.new(**attrs)
    end

    it 'renders one line per alert in briefer cadence' do
      tor = alert(
        kind: :warning, severity: :extreme, event: 'Tornado Warning',
        expires_at: Time.utc(2026, 4, 25, 19, 30), area_description: 'Essex, NJ',
        hail_size_in: 1.5, wind_gust_mph: 65.0, wind_gust_kt: 56.48,
        tornado_detection: :radar_indicated, headline: 'Tornado Warning ...'
      )
      svr = alert(
        kind: :warning, severity: :severe, event: 'Severe Thunderstorm Warning',
        expires_at: Time.utc(2026, 4, 25, 20, 0), area_description: 'Bergen, NJ',
        hail_size_in: 1.0, wind_gust_mph: 52.0, wind_gust_kt: 45.19,
        headline: 'Severe Thunderstorm Warning ...'
      )
      ffw = alert(
        kind: :warning, severity: :severe, event: 'Flash Flood Warning',
        expires_at: Time.utc(2026, 4, 25, 23, 0), area_description: 'Hudson, NJ',
        flash_flood_damage_threat: :considerable, headline: 'Flash Flood Warning ...'
      )
      watch = alert(
        kind: :watch, severity: :severe, event: 'Tornado Watch',
        expires_at: Time.utc(2026, 4, 25, 22, 0), area_description: 'NJ; NY; CT',
        headline: 'Tornado Watch 142 issued ...'
      )

      conv = Skywatch::Nimbus::Models::Convection.new(
        at: [40.688, -74.174], fetched_at: Time.now.utc,
        alerts: [svr, ffw, tor, watch] # intentionally out of severity order
      )

      output = Skywatch::Nimbus::Formatters::Text.format_convection(conv)

      expect(output).to eq(<<~BRIEF)
        TORNADO WARNING — Essex, NJ until 19:30Z. Radar-indicated; 1.50" hail, 56kt wind gust.
        SEVERE THUNDERSTORM WARNING — Bergen, NJ until 20:00Z. 1.00" hail, 45kt wind gust.
        FLASH FLOOD WARNING — Hudson, NJ until 23:00Z. Considerable damage threat.
        TORNADO WATCH #142 — NJ; NY; CT until 22:00Z.
      BRIEF
    end

    it 'returns the empty-state line when no alerts are active' do
      conv = Skywatch::Nimbus::Models::Convection.new(at: [0, 0], fetched_at: Time.now.utc, alerts: [])
      expect(Skywatch::Nimbus::Formatters::Text.format_convection(conv))
        .to eq("NO ACTIVE CONVECTIVE WARNINGS OR WATCHES.\n")
    end
  end

  describe 'convection phrase helpers' do
    let(:warning) do
      Skywatch::Nimbus::Models::ConvectiveAlert.new(
        kind: :warning, event: 'Tornado Warning',
        expires_at: Time.utc(2026, 4, 25, 19, 30),
        area_description: 'Essex, NJ',
        hail_size_in: 1.5, wind_gust_mph: 65.0, wind_gust_kt: 65.0,
        tornado_detection: :radar_indicated,
        thunderstorm_damage_threat: :considerable,
        headline: 'Tornado Warning issued ...'
      )
    end
    let(:watch) do
      Skywatch::Nimbus::Models::ConvectiveAlert.new(
        kind: :watch, event: 'Tornado Watch',
        expires_at: Time.utc(2026, 4, 25, 22, 0),
        area_description: 'NJ; NY; CT',
        headline: 'Tornado Watch 142 issued April 25 at 1:30PM EDT ' \
                  'until April 25 at 10:00PM EDT by NWS Storm Prediction Center'
      )
    end

    it 'formats the until-time helper as HH:MMZ' do
      expect(Skywatch::Nimbus::Formatters::Text.send(:until_phrase, warning)).to eq('until 19:30Z')
    end

    it 'formats hail and wind gust phrases' do
      expect(Skywatch::Nimbus::Formatters::Text.send(:hail_phrase, warning)).to eq('1.50" hail')
      expect(Skywatch::Nimbus::Formatters::Text.send(:wind_gust_phrase, warning)).to eq('65kt wind gust')
    end

    it 'formats tornado detection' do
      expect(Skywatch::Nimbus::Formatters::Text.send(:tornado_phrase, warning)).to eq('Radar-indicated')
    end

    it 'formats damage threat' do
      expect(Skywatch::Nimbus::Formatters::Text.send(:damage_threat_phrase, warning))
        .to eq('Considerable damage threat')
    end

    it 'extracts watch number from headline' do
      expect(Skywatch::Nimbus::Formatters::Text.send(:watch_number, watch)).to eq(142)
    end

    it 'returns nil when watch number is absent' do
      empty_watch = Skywatch::Nimbus::Models::ConvectiveAlert.new(kind: :watch, event: 'Tornado Watch', headline: '')
      expect(Skywatch::Nimbus::Formatters::Text.send(:watch_number, empty_watch)).to be_nil
    end
  end
end
