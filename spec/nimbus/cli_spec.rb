# frozen_string_literal: true

RSpec.describe Skywatch::Nimbus::CLI do
  before do
    stub_request(:get, 'https://www.spc.noaa.gov/products/outlook/day1otlk_cat.lyr.geojson')
      .to_return(status: 200,
                 body: File.read('spec/fixtures/spc/day1_synthetic.geojson'),
                 headers: { 'Content-Type' => 'application/geo+json' })
  end

  describe 'outlook command' do
    it 'renders every outlook in text format' do
      output = capture_stdout do
        described_class.start(['outlook', '1', '--format', 'text'])
      end
      expect(output).to include('OUTLOOK DAY 1: MRGL')
      expect(output).to include('OUTLOOK DAY 1: SLGT')
    end

    it 'renders every outlook in JSON format' do
      output = capture_stdout do
        described_class.start(['outlook', '1', '--format', 'json'])
      end
      parsed = JSON.parse(output)
      expect(parsed).to be_an(Array)
      expect(parsed.map { |o| o['label'] }).to eq(%w[MRGL SLGT])
    end

    it 'with --at returns the highest-risk covering outlook in text format' do
      output = capture_stdout do
        described_class.start(['outlook', '1', '--at', '40.7,-74.0', '--format', 'text'])
      end
      expect(output).to include('OUTLOOK DAY 1: SLGT')
      expect(output).not_to include('OUTLOOK DAY 1: MRGL')
    end

    it 'with --at returns the covering outlook in JSON format (single object)' do
      output = capture_stdout do
        described_class.start(['outlook', '1', '--at', '40.7,-74.0', '--format', 'json'])
      end
      parsed = JSON.parse(output)
      expect(parsed).to be_a(Hash)
      expect(parsed['label']).to eq('SLGT')
    end

    it 'with --at outside any feature prints a "No outlook covers" message in text format' do
      output = capture_stdout do
        described_class.start(['outlook', '1', '--at', '30.0,-40.0', '--format', 'text'])
      end
      expect(output).to include('No outlook covers 30.0, -40.0')
    end

    it 'with --at outside any feature prints "null" in JSON format' do
      output = capture_stdout do
        described_class.start(['outlook', '1', '--at', '30.0,-40.0', '--format', 'json'])
      end
      expect(output.strip).to eq('null')
    end
  end

  describe 'storms command' do
    before do
      stub_request(:get, 'https://www.spc.noaa.gov/climo/reports/today.csv')
        .to_return(status: 200,
                   body: File.read('spec/fixtures/spc/sample.csv'),
                   headers: { 'Content-Type' => 'text/csv' })
    end

    it 'renders all reports in text format by default' do
      output = capture_stdout { described_class.start(['storms', '--format', 'text']) }
      expect(output).to include('TORNADO EF2')
      expect(output).to include('WIND 65mph')
      expect(output).to include('HAIL 1.75"')
    end

    it 'renders all reports as a JSON array' do
      output = capture_stdout { described_class.start(['storms', '--format', 'json']) }
      parsed = JSON.parse(output)
      expect(parsed).to be_an(Array)
      expect(parsed.length).to eq(5)
    end

    it 'filters by --type tornado' do
      output = capture_stdout { described_class.start(['storms', '--type', 'tornado', '--format', 'json']) }
      parsed = JSON.parse(output)
      expect(parsed.length).to eq(1)
      expect(parsed.first['type']).to eq('tornado')
    end

    it 'filters by --near and --radius' do
      output = capture_stdout do
        described_class.start(['storms', '--near', '40.7,-74.0', '--radius', '100', '--format', 'json'])
      end
      parsed = JSON.parse(output)
      expect(parsed.length).to eq(3)
      expect(parsed.map { |r| r['state'] }).to all(satisfy { |s| %w[NJ NY].include?(s) })
    end

    it 'fetches YYMMDD.csv when --date is given' do
      stub_request(:get, 'https://www.spc.noaa.gov/climo/reports/260415.csv')
        .to_return(status: 200,
                   body: File.read('spec/fixtures/spc/sample.csv'),
                   headers: { 'Content-Type' => 'text/csv' })

      capture_stdout { described_class.start(['storms', '--date', '20260415', '--format', 'json']) }
      expect(WebMock).to have_requested(:get, 'https://www.spc.noaa.gov/climo/reports/260415.csv')
    end

    it 'prints a friendly empty message in text mode' do
      stub_request(:get, 'https://www.spc.noaa.gov/climo/reports/today.csv')
        .to_return(status: 200,
                   body: File.read('spec/fixtures/spc/today_empty.csv'),
                   headers: { 'Content-Type' => 'text/csv' })

      output = capture_stdout { described_class.start(['storms', '--format', 'text']) }
      expect(output).to include('No storm reports')
    end

    it 'prints [] in JSON mode when empty' do
      stub_request(:get, 'https://www.spc.noaa.gov/climo/reports/today.csv')
        .to_return(status: 200,
                   body: File.read('spec/fixtures/spc/today_empty.csv'),
                   headers: { 'Content-Type' => 'text/csv' })

      output = capture_stdout { described_class.start(['storms', '--format', 'json']) }
      expect(output.strip).to eq('[]')
    end
  end

  private

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end
end
