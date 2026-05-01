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

  describe 'smoke command' do
    let(:heavy_fixture) { File.read('spec/fixtures/hms_smoke/heavy_smoke_at_kmry.json') }
    let(:empty_fixture) { File.read('spec/fixtures/hms_smoke/empty.json') }

    it 'prints a one-line text summary on a TTY' do
      stub_request(:get, %r{services2\.arcgis\.com.*FeatureServer/0/query})
        .to_return(status: 200, body: heavy_fixture, headers: { 'Content-Type' => 'application/json' })

      output = capture_stdout { described_class.start(%w[smoke 36.587 -121.843 --format text]) }
      expect(output).to include('SMOKE Heavy')
      expect(output).to include('GOES-EAST')
    end

    it 'prints a JSON array when --format json' do
      stub_request(:get, %r{services2\.arcgis\.com.*FeatureServer/0/query})
        .to_return(status: 200, body: heavy_fixture, headers: { 'Content-Type' => 'application/json' })

      output = capture_stdout { described_class.start(%w[smoke 36.587 -121.843 --format json]) }
      parsed = JSON.parse(output)
      expect(parsed).to be_an(Array)
      expect(parsed.length).to eq(1)
      expect(parsed.first['density_raw']).to eq('Heavy')
    end

    it 'prints a friendly empty message in text mode' do
      stub_request(:get, %r{services2\.arcgis\.com.*FeatureServer/0/query})
        .to_return(status: 200, body: empty_fixture, headers: { 'Content-Type' => 'application/json' })

      output = capture_stdout { described_class.start(%w[smoke 37.62 -122.38 --format text]) }
      expect(output).to include('No smoke detected')
    end

    it 'prints [] in JSON mode when empty' do
      stub_request(:get, %r{services2\.arcgis\.com.*FeatureServer/0/query})
        .to_return(status: 200, body: empty_fixture, headers: { 'Content-Type' => 'application/json' })

      output = capture_stdout { described_class.start(%w[smoke 37.62 -122.38 --format json]) }
      expect(output.strip).to eq('[]')
    end

    it 'prints Error: ... and exits 1 when the source raises' do
      stub_request(:get, %r{services2\.arcgis\.com.*FeatureServer/0/query})
        .to_return(status: 500, body: '{"error":{"code":500}}')

      stderr = capture_stderr do
        expect do
          described_class.start(%w[smoke 37.62 -122.38 --format json])
        end.to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
      end
      expect(stderr).to include('Error:')
    end
  end

  describe 'convection' do
    let(:fixture) do
      File.read(File.expand_path('../fixtures/nws_alerts/multiple_active.json', __dir__))
    end

    before do
      stub_request(:get, %r{https://api\.weather\.gov/alerts/active})
        .to_return(status: 200, body: fixture, headers: { 'Content-Type' => 'application/geo+json' })
    end

    it 'prints briefer-cadence text by default on a TTY' do
      allow($stdout).to receive(:tty?).and_return(true)
      expect { Skywatch::Nimbus::CLI.start(%w[convection 40.688 -74.174]) }
        .to output(/TORNADO WARNING/).to_stdout
    end

    it 'prints JSON when --format json is passed' do
      expect { Skywatch::Nimbus::CLI.start(%w[convection 40.688 -74.174 --format json]) }
        .to output(/"warnings"/).to_stdout
    end

    it 'forwards --events filter to the source' do
      stub = stub_request(:get, 'https://api.weather.gov/alerts/active')
             .with(query: hash_including('event' => 'Tornado Warning'))
             .to_return(status: 200, body: '{"features":[]}', headers: { 'Content-Type' => 'application/geo+json' })

      Skywatch::Nimbus::CLI.start(
        ['convection', '40.688', '-74.174', '--events', 'Tornado Warning', '--format', 'json']
      )

      expect(stub).to have_been_requested
    end

    it 'prints the empty-state line on a TTY when nothing is active' do
      stub_request(:get, %r{https://api\.weather\.gov/alerts/active})
        .to_return(status: 200, body: '{"features":[]}', headers: { 'Content-Type' => 'application/geo+json' })

      expect { Skywatch::Nimbus::CLI.start(%w[convection 40.688 -74.174 --format text]) }
        .to output(/NO ACTIVE CONVECTIVE WARNINGS OR WATCHES/).to_stdout
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

  def capture_stderr
    original = $stderr
    $stderr = StringIO.new
    yield
    $stderr.string
  ensure
    $stderr = original
  end
end
