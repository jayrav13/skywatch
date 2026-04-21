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
        described_class.start(['outlook', '1', '--at', '40.7', '-74.0', '--format', 'text'])
      end
      expect(output).to include('OUTLOOK DAY 1: SLGT')
      expect(output).not_to include('OUTLOOK DAY 1: MRGL')
    end

    it 'with --at returns the covering outlook in JSON format (single object)' do
      output = capture_stdout do
        described_class.start(['outlook', '1', '--at', '40.7', '-74.0', '--format', 'json'])
      end
      parsed = JSON.parse(output)
      expect(parsed).to be_a(Hash)
      expect(parsed['label']).to eq('SLGT')
    end

    it 'with --at outside any feature prints a "No outlook covers" message in text format' do
      output = capture_stdout do
        described_class.start(['outlook', '1', '--at', '30.0', '-40.0', '--format', 'text'])
      end
      expect(output).to include('No outlook covers 30.0, -40.0')
    end

    it 'with --at outside any feature prints "null" in JSON format' do
      output = capture_stdout do
        described_class.start(['outlook', '1', '--at', '30.0', '-40.0', '--format', 'json'])
      end
      expect(output.strip).to eq('null')
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
