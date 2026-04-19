# Briefer Completion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close out the briefer domain by adding SIGMET, AIRMET, and AFD support, plus fixing the winds aloft text-format bug.

**Architecture:** Add three new sources (Sigmet, Airmet, Afd) following the existing thin-source pattern (HTTP fetch → model). AFD requires a second `Shared::Http` instance pointing at NWS (`api.weather.gov`). Add an `Afd` model; existing `Sigmet`/`Airmet` models already match the AWC JSON schema. Fix `Sources::WindsAloft` to use `get_raw` and parse the fixed-width text format that AWC actually returns. Add text formatters and Thor CLI subcommands. Wire everything through the top-level `Skywatch.<noun>` convenience API.

**Tech Stack:** Ruby, Faraday + faraday-retry (HTTP), Thor (CLI), RSpec + WebMock (tests). All sources cached via `Shared::Cache` wrapping `Shared::Http`.

**Spec:** `docs/superpowers/specs/2026-03-31-briefer-completion-design.md`. TFRs are explicitly out of scope (no stable public JSON API as of 2026-04-14 — the FAA ArcGIS service only retains `National_Defense_Airspace_TFR_Areas`, military-only).

---

## File Structure

**Created:**
- `lib/skywatch/briefer/sources/sigmet.rb`
- `lib/skywatch/briefer/sources/airmet.rb`
- `lib/skywatch/briefer/sources/afd.rb`
- `lib/skywatch/briefer/models/afd.rb`
- `spec/briefer/sources/sigmet_spec.rb`
- `spec/briefer/sources/airmet_spec.rb`
- `spec/briefer/sources/afd_spec.rb`
- `spec/briefer/models/afd_spec.rb`
- `spec/fixtures/sigmets/active.json` (replaces `convective.json` usage; keep `convective.json` as it's referenced by `sigmet_spec.rb`)
- `spec/fixtures/airmets/gairmet.json`
- `spec/fixtures/afd/okx_list.json`
- `spec/fixtures/afd/okx_product.json`
- `spec/fixtures/winds_aloft/low_level.txt` (raw text from AWC)

**Modified:**
- `lib/skywatch/briefer/sources/winds_aloft.rb` — switch to `get_raw`, parse fixed-width text
- `lib/skywatch/briefer/formatters/text.rb` — add `format_sigmet`, `format_airmet`, `format_afd`
- `lib/skywatch/briefer/cli.rb` — add `sigmets`, `airmets`, `afd` commands
- `lib/skywatch.rb` — require new files; add `Skywatch.sigmets`, `.airmets`, `.afd(wfo)`
- `spec/briefer/sources/winds_aloft_spec.rb` — use raw text fixture, update expectations
- `spec/briefer_spec.rb` — add specs for `.sigmets`, `.airmets`, `.afd`
- `spec/cli_spec.rb` — add CLI specs for `sigmets`, `airmets`, `afd`

**Deleted:** none

---

## Task 1: Fix winds aloft to parse text format

**Why first:** Pre-existing bug; isolated change; the existing fake-JSON fixture is misleading and must be replaced before anyone trusts winds aloft output.

**Files:**
- Replace: `spec/fixtures/winds_aloft/low_level.txt` (delete the existing `low_level.json` once tests are migrated)
- Modify: `lib/skywatch/briefer/sources/winds_aloft.rb`
- Modify: `spec/briefer/sources/winds_aloft_spec.rb`

### Real API behavior (verified 2026-04-14)

`GET https://aviationweather.gov/api/data/windtemp?region=all&level=low&fcst=06&format=json` returns `Content-Type: text/plain` with this format:

```
000
FBUS31 KWNO 140801
FD1US1
DATA BASED ON 140600Z
VALID 141200Z   FOR USE 0800-1500Z. TEMPS NEG ABV 24000

FT  3000    6000    9000   12000   18000   24000  30000  34000  39000
ABI      2319+17 2310+11 2220+03 2540-12 2347-22 246138 246748 247959
ACK 3014 2719+10 2724+03 2824-01 2927-14 3044-25 305541 305950 296361
JFK      2823+09 2723+04 2623-01 2735-15 2841-25 285341 285750 286261
```

- Header is 6 non-data lines ending with the `FT 3000 6000 ...` line
- Each data row: 3-letter station ID, then up to 9 fixed-width altitude columns
- Altitude column starts (0-indexed within the row, after the 3-char station + space):
  - 3000 → cols 4..7 (4 chars, no temp at this altitude)
  - 6000 → cols 9..15 (7 chars: dirsp+temp)
  - 9000 → cols 17..23
  - 12000 → cols 25..31
  - 18000 → cols 33..39
  - 24000 → cols 41..47
  - 30000 → cols 49..54 (6 chars, no sign — temp implied negative)
  - 34000 → cols 56..61
  - 39000 → cols 63..68
- A field of all spaces means "no data for this altitude at this station"
- The decode logic for an individual encoded cell already exists on the model: `Models::WindsAloft.decode(station_id:, altitude_ft:, encoded:)`. We only need to slice the line correctly and pass the slice to `decode`.

### Steps

- [x] **Step 1.1: Save a real text fixture**

Save a trimmed but representative text file (header + a handful of station rows including one with sparse data) at `spec/fixtures/winds_aloft/low_level.txt`. Use this exact content:

```
000
FBUS31 KWNO 140801
FD1US1
DATA BASED ON 140600Z
VALID 141200Z   FOR USE 0800-1500Z. TEMPS NEG ABV 24000

FT  3000    6000    9000   12000   18000   24000  30000  34000  39000
ACK 3014 2719+10 2724+03 2824-01 2927-14 3044-25 305541 305950 296361
JFK      2823+09 2723+04 2623-01 2735-15 2841-25 285341 285750 286261
ABI      2319+17 2310+11 2220+03 2540-12 2347-22 246138 246748 247959
```

(Note: ACK's 3000ft column is `3014` — wind 300° at 14kt, no temp. JFK and ABI have a blank 3000ft column.)

- [x] **Step 1.2: Write the failing source spec**

Replace `spec/briefer/sources/winds_aloft_spec.rb` with:

```ruby
# frozen_string_literal: true

RSpec.describe Skywatch::Briefer::Sources::WindsAloft do
  subject(:source) { described_class.new(client: Skywatch::Shared::Http.new) }

  let(:winds_text) { File.read('spec/fixtures/winds_aloft/low_level.txt') }

  before do
    stub_request(:get, 'https://aviationweather.gov/api/data/windtemp')
      .with(query: { region: 'all', level: 'low', fcst: '06', format: 'json' })
      .to_return(status: 200, body: winds_text, headers: { 'Content-Type' => 'text/plain' })
  end

  describe '#fetch' do
    it 'fetches winds for a station at all altitudes that have data' do
      winds = source.fetch('JFK')
      expect(winds).to all(be_a(Skywatch::Briefer::Models::WindsAloft))
      expect(winds.first.station_id).to eq('JFK')
      # JFK has no 3000ft data
      expect(winds.map(&:altitude_ft)).not_to include(3000)
      expect(winds.map(&:altitude_ft)).to include(6000, 9000, 12000, 18000, 24000, 30000, 34000, 39000)
    end

    it 'parses the 6000ft column correctly for JFK (280° @ 23kt, +9°C)' do
      winds = source.fetch('JFK', altitude_ft: 6000)
      expect(winds.size).to eq(1)
      w = winds.first
      expect(w.wind_direction_deg).to eq(280)
      expect(w.wind_speed_kt).to eq(23)
      expect(w.temperature_c).to eq(9)
    end

    it 'parses high-altitude implied-negative temps (ACK 30000ft: 300°@55kt, -41°C)' do
      winds = source.fetch('ACK', altitude_ft: 30_000)
      w = winds.first
      expect(w.wind_direction_deg).to eq(300)
      expect(w.wind_speed_kt).to eq(55)
      expect(w.temperature_c).to eq(-41)
    end

    it 'returns empty for unknown station' do
      expect(source.fetch('XXXX')).to eq([])
    end

    it 'is case-insensitive on station id' do
      expect(source.fetch('jfk')).not_to be_empty
    end
  end
end
```

- [x] **Step 1.3: Run the test, confirm it fails**

Run: `bundle exec rspec spec/briefer/sources/winds_aloft_spec.rb`
Expected: failures (source still calls `@client.get`, parses JSON, blows up on text body).

- [x] **Step 1.4: Rewrite the source**

Replace `lib/skywatch/briefer/sources/winds_aloft.rb` with:

```ruby
# frozen_string_literal: true

module Skywatch
  module Briefer
    module Sources
      class WindsAloft
        ENDPOINT = '/api/data/windtemp'
        TTL = 3600

        # Column slices within a data line (after the 3-char station id + 1 space).
        # Each tuple: [altitude_ft, start_index, length]
        COLUMNS = [
          [3000,  4,  4],
          [6000,  9,  7],
          [9000,  17, 7],
          [12_000, 25, 7],
          [18_000, 33, 7],
          [24_000, 41, 7],
          [30_000, 49, 6],
          [34_000, 56, 6],
          [39_000, 63, 6]
        ].freeze

        def initialize(client: Skywatch.client)
          @client = client
        end

        def fetch(station_id, altitude_ft: nil)
          body = @client.get_raw(ENDPOINT, { region: 'all', level: 'low', fcst: '06', format: 'json' }, ttl: TTL)
          line = find_station_line(body, station_id)
          return [] unless line

          rows_for(line, station_id, altitude_ft)
        end

        private

        def find_station_line(body, station_id)
          target = station_id.upcase
          body.each_line.find do |l|
            l[0, 3] == target && l.length > 4
          end
        end

        def rows_for(line, station_id, altitude_ft)
          COLUMNS.filter_map do |alt, start, len|
            next if altitude_ft && alt != altitude_ft

            cell = line[start, len].to_s.strip
            next if cell.empty?

            Skywatch::Briefer::Models::WindsAloft.decode(
              station_id: station_id.upcase, altitude_ft: alt, encoded: cell
            )
          end
        end
      end
    end
  end
end
```

- [x] **Step 1.5: Run tests, confirm they pass**

Run: `bundle exec rspec spec/briefer/sources/winds_aloft_spec.rb`
Expected: all green.

- [x] **Step 1.6: Delete the obsolete JSON fixture**

```bash
rm spec/fixtures/winds_aloft/low_level.json
```

- [x] **Step 1.7: Run the full suite + rubocop**

Run: `bundle exec rake`
Expected: all green. (If rubocop flags `Metrics/MethodLength` on `rows_for` or `find_station_line`, leave it — the methods are small.)

- [x] **Step 1.8: Commit**

```bash
git add lib/skywatch/briefer/sources/winds_aloft.rb \
        spec/briefer/sources/winds_aloft_spec.rb \
        spec/fixtures/winds_aloft/
git commit -m "Fix winds aloft source to parse fixed-width text response"
```

---

## Task 2: SIGMET source, formatter, CLI, convenience API

**Files:**
- Create: `lib/skywatch/briefer/sources/sigmet.rb`
- Create: `spec/briefer/sources/sigmet_spec.rb`
- Create: `spec/fixtures/sigmets/active.json`
- Modify: `lib/skywatch/briefer/formatters/text.rb`
- Modify: `lib/skywatch/briefer/cli.rb`
- Modify: `lib/skywatch.rb`
- Modify: `spec/briefer_spec.rb`
- Modify: `spec/cli_spec.rb`

### Real API behavior (verified 2026-04-14)

`GET https://aviationweather.gov/api/data/airsigmet?format=json` returns `Content-Type: application/json` — a JSON array. Field shape matches `Models::Sigmet.from_awc` exactly (already implemented and unit-tested).

### Steps

- [x] **Step 2.1: Save the SIGMET fixture**

Create `spec/fixtures/sigmets/active.json` containing an array of two SIGMET objects. Reuse `spec/fixtures/sigmets/convective.json` content for the first entry, and add a second non-convective entry. Exact content:

```json
[
  {
    "icaoId": "KKCI",
    "alphaChar": "E",
    "seriesId": "3E",
    "receiptTime": "2026-03-29T01:50:55.441Z",
    "creationTime": "2026-03-29T01:55:00.000Z",
    "validTimeFrom": 1774749300,
    "validTimeTo": 1774752899,
    "airSigmetType": "SIGMET",
    "hazard": "CONVECTIVE",
    "altitudeHi1": 32000,
    "altitudeHi2": 32000,
    "altitudeLow1": null,
    "altitudeLow2": null,
    "movementDir": 10,
    "movementSpd": 15,
    "rawAirSigmet": "WSUS31 KKCI 290155\nSIGE\nCONVECTIVE SIGMET 3E\nVALID UNTIL 0355Z\nFL AND CSTL WTRS\nFROM 30NNE TRV-70ENE PBI-20ENE PBI-20W TRV-30NNE TRV\nAREA TS MOV FROM 01015KT. TOPS TO FL320.",
    "postProcessFlag": 0,
    "severity": 5,
    "coords": [
      {"lat": 28.145, "lon": -80.272},
      {"lat": 27.122, "lon": -78.878},
      {"lat": 26.807, "lon": -79.746},
      {"lat": 27.679, "lon": -80.865},
      {"lat": 28.145, "lon": -80.272}
    ]
  },
  {
    "icaoId": "KKCI",
    "alphaChar": "T",
    "seriesId": "1T",
    "receiptTime": "2026-03-29T02:00:00.000Z",
    "creationTime": "2026-03-29T02:00:00.000Z",
    "validTimeFrom": 1774752900,
    "validTimeTo": 1774770900,
    "airSigmetType": "SIGMET",
    "hazard": "TURB",
    "altitudeHi1": 41000,
    "altitudeHi2": 41000,
    "altitudeLow1": 28000,
    "altitudeLow2": 28000,
    "movementDir": 270,
    "movementSpd": 40,
    "rawAirSigmet": "WSUS01 KKCI 290200\nSIGT\nSIGMET TANGO 1\nVALID UNTIL 0700Z\nFROM YQT TO YYB TO ALB TO BUF TO YQT\nMOD TO OCNL SEV TURB BTN FL280 AND FL410.",
    "postProcessFlag": 0,
    "severity": 4,
    "coords": [
      {"lat": 48.37, "lon": -89.32},
      {"lat": 46.36, "lon": -79.42},
      {"lat": 42.75, "lon": -73.80},
      {"lat": 42.94, "lon": -78.73},
      {"lat": 48.37, "lon": -89.32}
    ]
  }
]
```

- [x] **Step 2.2: Write the failing source spec**

Create `spec/briefer/sources/sigmet_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Skywatch::Briefer::Sources::Sigmet do
  subject(:source) { described_class.new(client: Skywatch::Shared::Http.new) }

  let(:response) { JSON.parse(File.read('spec/fixtures/sigmets/active.json')) }

  before do
    stub_request(:get, 'https://aviationweather.gov/api/data/airsigmet')
      .with(query: { format: 'json' })
      .to_return(status: 200, body: response.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  describe '#fetch' do
    it 'returns Sigmet models for every entry' do
      sigmets = source.fetch
      expect(sigmets.size).to eq(2)
      expect(sigmets).to all(be_a(Skywatch::Briefer::Models::Sigmet))
    end

    it 'parses hazards from both convective and non-convective SIGMETs' do
      sigmets = source.fetch
      expect(sigmets.map(&:hazard)).to contain_exactly('CONVECTIVE', 'TURB')
    end

    it 'raises ApiError on HTTP failure' do
      stub_request(:get, 'https://aviationweather.gov/api/data/airsigmet')
        .with(query: { format: 'json' })
        .to_return(status: 500, body: 'oops')
      expect { source.fetch }.to raise_error(Skywatch::ApiError)
    end
  end
end
```

- [x] **Step 2.3: Run, confirm fail**

Run: `bundle exec rspec spec/briefer/sources/sigmet_spec.rb`
Expected: `NameError: uninitialized constant Skywatch::Briefer::Sources::Sigmet`.

- [x] **Step 2.4: Implement the source**

Create `lib/skywatch/briefer/sources/sigmet.rb`:

```ruby
# frozen_string_literal: true

module Skywatch
  module Briefer
    module Sources
      class Sigmet
        ENDPOINT = '/api/data/airsigmet'
        TTL = 900

        def initialize(client: Skywatch.client)
          @client = client
        end

        def fetch
          data = @client.get(ENDPOINT, { format: 'json' }, ttl: TTL)
          data.map { |entry| Skywatch::Briefer::Models::Sigmet.from_awc(entry) }
        end
      end
    end
  end
end
```

- [x] **Step 2.5: Wire into autoload**

Edit `lib/skywatch.rb`. After the line `require_relative 'skywatch/briefer/sources/winds_aloft'` add:

```ruby
require_relative 'skywatch/briefer/sources/sigmet'
```

- [x] **Step 2.6: Run, confirm pass**

Run: `bundle exec rspec spec/briefer/sources/sigmet_spec.rb`
Expected: all green.

- [x] **Step 2.7: Add the formatter — failing test first**

Add to `spec/briefer/formatters/` a new file `spec/briefer/formatters/text_spec.rb` if it does not exist; otherwise append. (Check first: `ls spec/briefer/formatters/`.) For now, exercise it through the convenience API and CLI specs in later steps — skip a dedicated formatter spec to stay DRY with the existing pattern (no `text_spec.rb` exists today).

Instead, add to `lib/skywatch/briefer/formatters/text.rb`. Insert this method after `format_winds_aloft` and before `format_crosswind`:

```ruby
        def self.format_sigmet(sigmet) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
          alt = format_altitude_band(sigmet.altitude_low_ft, sigmet.altitude_hi_ft)
          from = sigmet.valid_from&.strftime('%d %b %H%MZ')
          to = sigmet.valid_to&.strftime('%d %b %H%MZ')
          movement = if sigmet.movement_dir_deg && sigmet.movement_speed_kt
                       "MOV #{sigmet.movement_dir_deg}°@#{sigmet.movement_speed_kt}kt"
                     else
                       'MOV STNR'
                     end
          <<~TEXT
            SIGMET #{sigmet.series_id} (#{sigmet.issuing_center}) — #{sigmet.hazard}
              Valid: #{from} to #{to}  Alt: #{alt}  #{movement}
              #{sigmet.raw}
          TEXT
        end

        def self.format_altitude_band(low, high)
          return '-' unless low || high
          return "SFC-FL#{format('%03d', high / 100)}" if low.nil? && high
          return "FL#{format('%03d', low / 100)}+" if high.nil? && low

          "FL#{format('%03d', low / 100)}-FL#{format('%03d', high / 100)}"
        end
```

Then add `format_altitude_band` to the `private_class_method` list at the bottom:

```ruby
        private_class_method :format_wind, :format_visibility, :format_ceiling, :number_with_commas,
                             :format_taf_clouds, :winds_aloft_row, :format_altitude_band
```

- [x] **Step 2.8: Add convenience API**

Edit `lib/skywatch.rb`. Inside the `class << self` block, after the `winds_aloft` method, add:

```ruby
    def sigmets
      Briefer::Sources::Sigmet.new.fetch
    end
```

- [x] **Step 2.9: Add convenience-API spec**

Append to `spec/briefer_spec.rb` (before the final `end`):

```ruby
  describe '.sigmets' do
    let(:data) { JSON.parse(File.read('spec/fixtures/sigmets/active.json')) }

    before do
      stub_request(:get, 'https://aviationweather.gov/api/data/airsigmet')
        .with(query: { format: 'json' })
        .to_return(status: 200, body: data.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns an array of Sigmet models' do
      sigmets = described_class.sigmets
      expect(sigmets).to all(be_a(Skywatch::Briefer::Models::Sigmet))
      expect(sigmets.map(&:hazard)).to include('CONVECTIVE')
    end
  end
```

- [x] **Step 2.10: Add the CLI command**

Edit `lib/skywatch/briefer/cli.rb`. After the `categories` method (before `private`), add:

```ruby
      desc 'sigmets', 'List active SIGMETs (US)'
      def sigmets
        sigmets = Skywatch.sigmets

        if output_format == 'json'
          puts JSON.pretty_generate(sigmets.map(&:to_h))
        elsif sigmets.empty?
          puts 'No active SIGMETs.'
        else
          sigmets.each { |s| print Skywatch::Briefer::Formatters::Text.format_sigmet(s) }
        end
      rescue Skywatch::Error => e
        warn "Error: #{e.message}"
        exit 1
      end
```

- [x] **Step 2.11: Add the CLI spec**

Append to `spec/cli_spec.rb` (inside the top-level `describe`, before the final `private`/`def capture_stdout`):

```ruby
  describe 'sigmets command' do
    let(:data) { JSON.parse(File.read('spec/fixtures/sigmets/active.json')) }

    before do
      stub_request(:get, 'https://aviationweather.gov/api/data/airsigmet')
        .with(query: { format: 'json' })
        .to_return(status: 200, body: data.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    it 'prints SIGMETs in text format' do
      output = capture_stdout { described_class.start(['sigmets', '--format', 'text']) }
      expect(output).to include('SIGMET')
      expect(output).to include('CONVECTIVE')
    end

    it 'prints SIGMETs in JSON format' do
      output = capture_stdout { described_class.start(['sigmets', '--format', 'json']) }
      parsed = JSON.parse(output)
      expect(parsed.size).to eq(2)
      expect(parsed.first['hazard']).to eq('CONVECTIVE')
    end
  end
```

- [x] **Step 2.12: Run the full suite + rubocop**

Run: `bundle exec rake`
Expected: all green.

- [x] **Step 2.13: Commit**

```bash
git add lib/skywatch/briefer/sources/sigmet.rb \
        lib/skywatch/briefer/formatters/text.rb \
        lib/skywatch/briefer/cli.rb \
        lib/skywatch.rb \
        spec/briefer/sources/sigmet_spec.rb \
        spec/briefer_spec.rb \
        spec/cli_spec.rb \
        spec/fixtures/sigmets/active.json
git commit -m "Add SIGMET source, formatter, CLI, and convenience API"
```

---

## Task 3: AIRMET source, formatter, CLI (with --product filter), convenience API

**Files:**
- Create: `lib/skywatch/briefer/sources/airmet.rb`
- Create: `spec/briefer/sources/airmet_spec.rb`
- Create: `spec/fixtures/airmets/gairmet.json`
- Modify: `lib/skywatch/briefer/formatters/text.rb`
- Modify: `lib/skywatch/briefer/cli.rb`
- Modify: `lib/skywatch.rb`
- Modify: `spec/briefer_spec.rb`
- Modify: `spec/cli_spec.rb`

### Real API behavior (verified 2026-04-14)

`GET https://aviationweather.gov/api/data/gairmet?format=json` returns a JSON array. Field shape matches `Models::Airmet.from_awc`.

### Steps

- [x] **Step 3.1: Save the AIRMET fixture**

Create `spec/fixtures/airmets/gairmet.json`. We need at least one of each product (SIERRA, TANGO, ZULU) so the `--product` filter spec is meaningful. Use this content:

```json
[
  {
    "tag": "1E",
    "forecastHour": 3,
    "validTime": "2026-04-14T12:00:00.000Z",
    "hazard": "IFR",
    "geometryType": "AREA",
    "latlonpairs": 4,
    "frequency": "",
    "severity": "",
    "due_to": "CIG BLW 010/VIS BLW 3SM PCPN/BR/FG",
    "status": "",
    "top": "",
    "base": "",
    "fzltop": "",
    "fzlbase": "",
    "level": "",
    "receiptTime": 1776165895,
    "issueTime": 1776165840,
    "expireTime": 1776178800,
    "product": "SIERRA",
    "geom": "AREA",
    "coords": [
      {"lat": "49.27", "lon": "-94.90"},
      {"lat": "48.40", "lon": "-92.40"},
      {"lat": "48.37", "lon": "-91.82"},
      {"lat": "49.27", "lon": "-94.90"}
    ]
  },
  {
    "tag": "2T",
    "forecastHour": 3,
    "validTime": "2026-04-14T12:00:00.000Z",
    "hazard": "TURB-LO",
    "geometryType": "AREA",
    "latlonpairs": 4,
    "frequency": "",
    "severity": "MOD",
    "due_to": "WND",
    "status": "",
    "top": "FL180",
    "base": "FL050",
    "fzltop": "",
    "fzlbase": "",
    "level": "",
    "receiptTime": 1776165895,
    "issueTime": 1776165840,
    "expireTime": 1776178800,
    "product": "TANGO",
    "geom": "AREA",
    "coords": [
      {"lat": "44.0", "lon": "-90.0"},
      {"lat": "43.0", "lon": "-88.0"},
      {"lat": "42.0", "lon": "-89.0"},
      {"lat": "44.0", "lon": "-90.0"}
    ]
  },
  {
    "tag": "3Z",
    "forecastHour": 3,
    "validTime": "2026-04-14T12:00:00.000Z",
    "hazard": "ICE",
    "geometryType": "AREA",
    "latlonpairs": 4,
    "frequency": "",
    "severity": "MOD",
    "due_to": "",
    "status": "",
    "top": "FL200",
    "base": "FL080",
    "fzltop": "10000",
    "fzlbase": "5000",
    "level": "",
    "receiptTime": 1776165895,
    "issueTime": 1776165840,
    "expireTime": 1776178800,
    "product": "ZULU",
    "geom": "AREA",
    "coords": [
      {"lat": 41.0, "lon": -75.0},
      {"lat": 40.5, "lon": -74.0},
      {"lat": 40.0, "lon": -75.0},
      {"lat": 41.0, "lon": -75.0}
    ]
  }
]
```

- [x] **Step 3.2: Write the failing source spec**

Create `spec/briefer/sources/airmet_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Skywatch::Briefer::Sources::Airmet do
  subject(:source) { described_class.new(client: Skywatch::Shared::Http.new) }

  let(:response) { JSON.parse(File.read('spec/fixtures/airmets/gairmet.json')) }

  before do
    stub_request(:get, 'https://aviationweather.gov/api/data/gairmet')
      .with(query: { format: 'json' })
      .to_return(status: 200, body: response.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  describe '#fetch' do
    it 'returns Airmet models for every entry' do
      airmets = source.fetch
      expect(airmets.size).to eq(3)
      expect(airmets).to all(be_a(Skywatch::Briefer::Models::Airmet))
    end

    it 'covers all three product types' do
      products = source.fetch.map(&:product)
      expect(products).to contain_exactly(:sierra, :tango, :zulu)
    end
  end
end
```

- [x] **Step 3.3: Run, confirm fail**

Run: `bundle exec rspec spec/briefer/sources/airmet_spec.rb`
Expected: `NameError: uninitialized constant Skywatch::Briefer::Sources::Airmet`.

- [x] **Step 3.4: Implement the source**

Create `lib/skywatch/briefer/sources/airmet.rb`:

```ruby
# frozen_string_literal: true

module Skywatch
  module Briefer
    module Sources
      class Airmet
        ENDPOINT = '/api/data/gairmet'
        TTL = 900

        def initialize(client: Skywatch.client)
          @client = client
        end

        def fetch
          data = @client.get(ENDPOINT, { format: 'json' }, ttl: TTL)
          data.map { |entry| Skywatch::Briefer::Models::Airmet.from_awc(entry) }
        end
      end
    end
  end
end
```

- [x] **Step 3.5: Wire into autoload**

Edit `lib/skywatch.rb`. After `require_relative 'skywatch/briefer/sources/sigmet'` (added in Task 2), add:

```ruby
require_relative 'skywatch/briefer/sources/airmet'
```

- [x] **Step 3.6: Run, confirm pass**

Run: `bundle exec rspec spec/briefer/sources/airmet_spec.rb`
Expected: all green.

- [x] **Step 3.7: Add the formatter**

Add to `lib/skywatch/briefer/formatters/text.rb`. Insert after `format_sigmet` and before `format_altitude_band`:

```ruby
        def self.format_airmet(airmet) # rubocop:disable Metrics/AbcSize
          product_label = airmet.product.to_s.upcase
          severity = airmet.severity ? " #{airmet.severity}" : ''
          due = airmet.due_to ? " — #{airmet.due_to}" : ''
          alt = format_airmet_altitude(airmet)
          valid = airmet.valid_at&.strftime('%d %b %H%MZ')
          <<~TEXT
            G-AIRMET #{airmet.tag} #{product_label} (#{airmet.hazard})#{severity}#{due}
              Valid: #{valid}  Alt: #{alt}  FL: #{airmet.forecast_hour}h
          TEXT
        end

        def self.format_airmet_altitude(airmet)
          return '-' unless airmet.base || airmet.top
          return "SFC-#{airmet.top}" if airmet.base.nil?
          return "#{airmet.base}+" if airmet.top.nil?

          "#{airmet.base}-#{airmet.top}"
        end
```

Add `format_airmet_altitude` to the `private_class_method` list:

```ruby
        private_class_method :format_wind, :format_visibility, :format_ceiling, :number_with_commas,
                             :format_taf_clouds, :winds_aloft_row, :format_altitude_band,
                             :format_airmet_altitude
```

- [x] **Step 3.8: Add convenience API**

Edit `lib/skywatch.rb`. After the `sigmets` method added in Task 2, add:

```ruby
    def airmets
      Briefer::Sources::Airmet.new.fetch
    end
```

- [x] **Step 3.9: Add convenience-API spec**

Append to `spec/briefer_spec.rb`:

```ruby
  describe '.airmets' do
    let(:data) { JSON.parse(File.read('spec/fixtures/airmets/gairmet.json')) }

    before do
      stub_request(:get, 'https://aviationweather.gov/api/data/gairmet')
        .with(query: { format: 'json' })
        .to_return(status: 200, body: data.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns an array of Airmet models with all three products' do
      airmets = described_class.airmets
      expect(airmets).to all(be_a(Skywatch::Briefer::Models::Airmet))
      expect(airmets.map(&:product)).to contain_exactly(:sierra, :tango, :zulu)
    end
  end
```

- [x] **Step 3.10: Add the CLI command**

Edit `lib/skywatch/briefer/cli.rb`. After the `sigmets` method added in Task 2, add:

```ruby
      desc 'airmets', 'List active G-AIRMETs'
      option :product, type: :string, enum: %w[sierra tango zulu], desc: 'Filter by product'
      def airmets # rubocop:disable Metrics/MethodLength
        airmets = Skywatch.airmets
        airmets = airmets.select { |a| a.product == options[:product].to_sym } if options[:product]

        if output_format == 'json'
          puts JSON.pretty_generate(airmets.map(&:to_h))
        elsif airmets.empty?
          puts 'No active G-AIRMETs.'
        else
          airmets.each { |a| print Skywatch::Briefer::Formatters::Text.format_airmet(a) }
        end
      rescue Skywatch::Error => e
        warn "Error: #{e.message}"
        exit 1
      end
```

- [x] **Step 3.11: Add the CLI spec**

Append to `spec/cli_spec.rb`:

```ruby
  describe 'airmets command' do
    let(:data) { JSON.parse(File.read('spec/fixtures/airmets/gairmet.json')) }

    before do
      stub_request(:get, 'https://aviationweather.gov/api/data/gairmet')
        .with(query: { format: 'json' })
        .to_return(status: 200, body: data.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    it 'prints AIRMETs in text format' do
      output = capture_stdout { described_class.start(['airmets', '--format', 'text']) }
      expect(output).to include('G-AIRMET')
      expect(output).to include('SIERRA')
      expect(output).to include('TANGO')
      expect(output).to include('ZULU')
    end

    it 'filters by --product' do
      output = capture_stdout { described_class.start(['airmets', '--product', 'tango', '--format', 'json']) }
      parsed = JSON.parse(output)
      expect(parsed.size).to eq(1)
      expect(parsed.first['product']).to eq('tango')
    end
  end
```

- [x] **Step 3.12: Run the full suite + rubocop**

Run: `bundle exec rake`
Expected: all green.

- [x] **Step 3.13: Commit**

```bash
git add lib/skywatch/briefer/sources/airmet.rb \
        lib/skywatch/briefer/formatters/text.rb \
        lib/skywatch/briefer/cli.rb \
        lib/skywatch.rb \
        spec/briefer/sources/airmet_spec.rb \
        spec/briefer_spec.rb \
        spec/cli_spec.rb \
        spec/fixtures/airmets/gairmet.json
git commit -m "Add AIRMET source, formatter, CLI, and convenience API"
```

---

## Task 4: AFD model, source, formatter, CLI, convenience API

**Files:**
- Create: `lib/skywatch/briefer/models/afd.rb`
- Create: `lib/skywatch/briefer/sources/afd.rb`
- Create: `spec/briefer/models/afd_spec.rb`
- Create: `spec/briefer/sources/afd_spec.rb`
- Create: `spec/fixtures/afd/okx_list.json`
- Create: `spec/fixtures/afd/okx_product.json`
- Modify: `lib/skywatch/briefer/formatters/text.rb`
- Modify: `lib/skywatch/briefer/cli.rb`
- Modify: `lib/skywatch.rb`
- Modify: `spec/briefer_spec.rb`
- Modify: `spec/cli_spec.rb`

### Real API behavior (verified 2026-04-14)

Two-step JSON-LD fetch against `https://api.weather.gov` (different host than AWC):

1. `GET /products/types/AFD/locations/OKX` → JSON-LD with `@graph` array; each entry has `@id` (URL), `id` (UUID), `issuingOffice`, `issuanceTime`, `productCode`, `productName`. The first element is the most recent.
2. `GET /products/{uuid}` → JSON-LD with `productText` (full body).

Content-Type is `application/ld+json` but the body is plain JSON — `JSON.parse` works.

The shared HTTP client defaults to `https://aviationweather.gov`. We need a separate `Shared::Http` instance for NWS. The `Source::Afd` will accept an optional `client:` and default to a fresh `Shared::Http.new(base_url: 'https://api.weather.gov')` (no caching wrapper for v1; we can add a cache later if needed — sources elsewhere use `Skywatch.client` which is cached, but that one is bound to the AWC base URL).

### Steps

- [x] **Step 4.1: Save fixtures**

Create `spec/fixtures/afd/okx_list.json`:

```json
{
  "@context": {
    "@version": "1.1",
    "@vocab": "https://api.weather.gov/ontology#"
  },
  "@graph": [
    {
      "@id": "https://api.weather.gov/products/d0ba4c68-b615-4054-a081-e4203c6c273a",
      "id": "d0ba4c68-b615-4054-a081-e4203c6c273a",
      "wmoCollectiveId": "FXUS61",
      "issuingOffice": "KOKX",
      "issuanceTime": "2026-04-14T07:22:00+00:00",
      "productCode": "AFD",
      "productName": "Area Forecast Discussion"
    },
    {
      "@id": "https://api.weather.gov/products/487357f3-4a4c-455b-9721-87d18a42efff",
      "id": "487357f3-4a4c-455b-9721-87d18a42efff",
      "wmoCollectiveId": "FXUS61",
      "issuingOffice": "KOKX",
      "issuanceTime": "2026-04-14T02:50:00+00:00",
      "productCode": "AFD",
      "productName": "Area Forecast Discussion"
    }
  ]
}
```

Create `spec/fixtures/afd/okx_product.json`:

```json
{
  "@context": {
    "@version": "1.1",
    "@vocab": "https://api.weather.gov/ontology#"
  },
  "@id": "https://api.weather.gov/products/d0ba4c68-b615-4054-a081-e4203c6c273a",
  "id": "d0ba4c68-b615-4054-a081-e4203c6c273a",
  "wmoCollectiveId": "FXUS61",
  "issuingOffice": "KOKX",
  "issuanceTime": "2026-04-14T07:22:00+00:00",
  "productCode": "AFD",
  "productName": "Area Forecast Discussion",
  "productText": "\n000\nFXUS61 KOKX 140722\nAFDOKX\n\nArea Forecast Discussion\nNational Weather Service New York NY\n322 AM EDT Tue Apr 14 2026\n\n.KEY MESSAGES...\n1) Well above normal temperatures thru Friday.\n2) Some showers and thunderstorms possible thru the period.\n\n&&\n\n.SYNOPSIS...\nHigh pressure offshore with warm advection.\n\n$$\n"
}
```

- [x] **Step 4.2: Write the failing model spec**

Create `spec/briefer/models/afd_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Skywatch::Briefer::Models::Afd do
  let(:product_data) { JSON.parse(File.read('spec/fixtures/afd/okx_product.json')) }

  describe '.from_nws' do
    subject(:afd) { described_class.from_nws(product_data) }

    it 'extracts WFO from issuingOffice (stripping K prefix)' do
      expect(afd.wfo).to eq('OKX')
    end

    it 'parses issuance time' do
      expect(afd.issued_at).to eq(Time.utc(2026, 4, 14, 7, 22, 0))
    end

    it 'preserves the full product text' do
      expect(afd.text).to include('Area Forecast Discussion')
      expect(afd.text).to include('.KEY MESSAGES...')
    end

    it 'reports the product name' do
      expect(afd.product_name).to eq('Area Forecast Discussion')
    end
  end

  describe '#to_h' do
    subject(:afd) { described_class.from_nws(product_data) }

    it 'serializes all fields' do
      h = afd.to_h
      expect(h[:wfo]).to eq('OKX')
      expect(h[:product_name]).to eq('Area Forecast Discussion')
      expect(h[:issued_at]).to eq('2026-04-14T07:22:00Z')
      expect(h[:text]).to include('Area Forecast Discussion')
    end
  end
end
```

- [x] **Step 4.3: Run, confirm fail**

Run: `bundle exec rspec spec/briefer/models/afd_spec.rb`
Expected: `NameError: uninitialized constant Skywatch::Briefer::Models::Afd`.

- [x] **Step 4.4: Implement the model**

Create `lib/skywatch/briefer/models/afd.rb`:

```ruby
# frozen_string_literal: true

require 'time'

module Skywatch
  module Briefer
    module Models
      class Afd
        attr_reader :wfo, :product_name, :issued_at, :text

        def self.from_nws(data)
          office = data['issuingOffice'].to_s
          wfo = office.start_with?('K') ? office[1..] : office
          new(
            wfo: wfo,
            product_name: data['productName'],
            issued_at: Time.parse(data['issuanceTime']).utc,
            text: data['productText']
          )
        end

        def initialize(wfo:, product_name:, issued_at:, text:)
          @wfo = wfo
          @product_name = product_name
          @issued_at = issued_at
          @text = text
        end

        def to_h
          {
            wfo: wfo,
            product_name: product_name,
            issued_at: issued_at&.iso8601,
            text: text
          }
        end

        def to_json(*)
          to_h.to_json(*)
        end
      end
    end
  end
end
```

- [x] **Step 4.5: Wire into autoload**

Edit `lib/skywatch.rb`. After `require_relative 'skywatch/briefer/models/tfr'` add:

```ruby
require_relative 'skywatch/briefer/models/afd'
```

- [x] **Step 4.6: Run model spec, confirm pass**

Run: `bundle exec rspec spec/briefer/models/afd_spec.rb`
Expected: all green.

- [x] **Step 4.7: Write the failing source spec**

Create `spec/briefer/sources/afd_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Skywatch::Briefer::Sources::Afd do
  subject(:source) { described_class.new }

  let(:list) { JSON.parse(File.read('spec/fixtures/afd/okx_list.json')) }
  let(:product) { JSON.parse(File.read('spec/fixtures/afd/okx_product.json')) }

  before do
    stub_request(:get, 'https://api.weather.gov/products/types/AFD/locations/OKX')
      .to_return(status: 200, body: list.to_json, headers: { 'Content-Type' => 'application/ld+json' })
    stub_request(:get, 'https://api.weather.gov/products/d0ba4c68-b615-4054-a081-e4203c6c273a')
      .to_return(status: 200, body: product.to_json, headers: { 'Content-Type' => 'application/ld+json' })
  end

  describe '#fetch' do
    it 'returns the most recent AFD for the WFO' do
      afd = source.fetch('OKX')
      expect(afd).to be_a(Skywatch::Briefer::Models::Afd)
      expect(afd.wfo).to eq('OKX')
      expect(afd.text).to include('Area Forecast Discussion')
    end

    it 'upcases the WFO identifier' do
      afd = source.fetch('okx')
      expect(afd.wfo).to eq('OKX')
    end

    it 'raises when no products are returned' do
      stub_request(:get, 'https://api.weather.gov/products/types/AFD/locations/XXX')
        .to_return(status: 200, body: { '@graph' => [] }.to_json,
                   headers: { 'Content-Type' => 'application/ld+json' })

      expect { source.fetch('XXX') }.to raise_error(Skywatch::Error, /No AFD/)
    end
  end
end
```

- [x] **Step 4.8: Run, confirm fail**

Run: `bundle exec rspec spec/briefer/sources/afd_spec.rb`
Expected: `NameError: uninitialized constant Skywatch::Briefer::Sources::Afd`.

- [x] **Step 4.9: Implement the source**

Create `lib/skywatch/briefer/sources/afd.rb`:

```ruby
# frozen_string_literal: true

module Skywatch
  module Briefer
    module Sources
      class Afd
        BASE_URL = 'https://api.weather.gov'
        LIST_TTL = 3600
        PRODUCT_TTL = 3600

        def initialize(client: Skywatch::Shared::Http.new(base_url: BASE_URL))
          @client = client
        end

        def fetch(wfo)
          wfo = wfo.upcase
          list = @client.get("/products/types/AFD/locations/#{wfo}", {}, ttl: LIST_TTL)
          entries = list['@graph'] || []
          raise Skywatch::Error, "No AFD available for WFO #{wfo}" if entries.empty?

          product = @client.get(URI(entries.first['@id']).path, {}, ttl: PRODUCT_TTL)
          Skywatch::Briefer::Models::Afd.from_nws(product)
        end
      end
    end
  end
end
```

(`URI(...).path` strips host/scheme so the request goes through the configured base URL.)

- [x] **Step 4.10: Wire into autoload**

Edit `lib/skywatch.rb`. After `require_relative 'skywatch/briefer/sources/airmet'` (added in Task 3), add:

```ruby
require_relative 'skywatch/briefer/sources/afd'
```

- [x] **Step 4.11: Run source spec, confirm pass**

Run: `bundle exec rspec spec/briefer/sources/afd_spec.rb`
Expected: all green.

- [x] **Step 4.12: Add the formatter**

Add to `lib/skywatch/briefer/formatters/text.rb`. Insert after `format_airmet`:

```ruby
        def self.format_afd(afd)
          header = "#{afd.product_name} — WFO #{afd.wfo} (issued #{afd.issued_at.strftime('%d %b %Y %H%MZ')})"
          rule = '=' * header.length
          "#{header}\n#{rule}\n#{afd.text}\n"
        end
```

- [x] **Step 4.13: Add convenience API**

Edit `lib/skywatch.rb`. After the `airmets` method (added in Task 3), add:

```ruby
    def afd(wfo)
      Briefer::Sources::Afd.new.fetch(wfo)
    end
```

- [x] **Step 4.14: Add convenience-API spec**

Append to `spec/briefer_spec.rb`:

```ruby
  describe '.afd' do
    let(:list) { JSON.parse(File.read('spec/fixtures/afd/okx_list.json')) }
    let(:product) { JSON.parse(File.read('spec/fixtures/afd/okx_product.json')) }

    before do
      stub_request(:get, 'https://api.weather.gov/products/types/AFD/locations/OKX')
        .to_return(status: 200, body: list.to_json, headers: { 'Content-Type' => 'application/ld+json' })
      stub_request(:get, 'https://api.weather.gov/products/d0ba4c68-b615-4054-a081-e4203c6c273a')
        .to_return(status: 200, body: product.to_json, headers: { 'Content-Type' => 'application/ld+json' })
    end

    it 'returns an Afd model for the requested WFO' do
      afd = described_class.afd('OKX')
      expect(afd).to be_a(Skywatch::Briefer::Models::Afd)
      expect(afd.wfo).to eq('OKX')
    end
  end
```

- [x] **Step 4.15: Add the CLI command**

Edit `lib/skywatch/briefer/cli.rb`. After the `airmets` method, add:

```ruby
      desc 'afd WFO', 'Show the latest Area Forecast Discussion for a Weather Forecast Office'
      def afd(wfo)
        afd = Skywatch.afd(wfo)

        if output_format == 'json'
          puts JSON.pretty_generate(afd.to_h)
        else
          print Skywatch::Briefer::Formatters::Text.format_afd(afd)
        end
      rescue Skywatch::Error => e
        warn "Error: #{e.message}"
        exit 1
      end
```

- [x] **Step 4.16: Add the CLI spec**

Append to `spec/cli_spec.rb`:

```ruby
  describe 'afd command' do
    let(:list) { JSON.parse(File.read('spec/fixtures/afd/okx_list.json')) }
    let(:product) { JSON.parse(File.read('spec/fixtures/afd/okx_product.json')) }

    before do
      stub_request(:get, 'https://api.weather.gov/products/types/AFD/locations/OKX')
        .to_return(status: 200, body: list.to_json, headers: { 'Content-Type' => 'application/ld+json' })
      stub_request(:get, 'https://api.weather.gov/products/d0ba4c68-b615-4054-a081-e4203c6c273a')
        .to_return(status: 200, body: product.to_json, headers: { 'Content-Type' => 'application/ld+json' })
    end

    it 'prints AFD in text format' do
      output = capture_stdout { described_class.start(['afd', 'OKX', '--format', 'text']) }
      expect(output).to include('Area Forecast Discussion')
      expect(output).to include('WFO OKX')
      expect(output).to include('.KEY MESSAGES...')
    end

    it 'prints AFD in JSON format' do
      output = capture_stdout { described_class.start(['afd', 'OKX', '--format', 'json']) }
      parsed = JSON.parse(output)
      expect(parsed['wfo']).to eq('OKX')
      expect(parsed['text']).to include('Area Forecast Discussion')
    end
  end
```

- [x] **Step 4.17: Run the full suite + rubocop**

Run: `bundle exec rake`
Expected: all green.

- [x] **Step 4.18: Commit**

```bash
git add lib/skywatch/briefer/models/afd.rb \
        lib/skywatch/briefer/sources/afd.rb \
        lib/skywatch/briefer/formatters/text.rb \
        lib/skywatch/briefer/cli.rb \
        lib/skywatch.rb \
        spec/briefer/models/afd_spec.rb \
        spec/briefer/sources/afd_spec.rb \
        spec/briefer_spec.rb \
        spec/cli_spec.rb \
        spec/fixtures/afd/
git commit -m "Add AFD model, source, formatter, CLI, and convenience API"
```

---

## Task 5: Final smoke check + README touch

**Files:** none beyond a doc tweak.

- [x] **Step 5.1: Smoke-test the new CLI commands against fixtures via the test suite**

Run: `bundle exec rake`
Expected: full suite green, rubocop clean.

- [ ] **Step 5.2: Live smoke (optional but recommended)** — *not run; optional, and the test suite covers behavior via fixtures.*

Run each command against the live API and eyeball the output:

```bash
bundle exec exe/skywatch weather sigmets --format text | head -30
bundle exec exe/skywatch weather airmets --product sierra --format text | head -30
bundle exec exe/skywatch weather afd OKX --format text | head -40
bundle exec exe/skywatch weather winds JFK --format text
```

If any blow up, file an issue and stop — do not commit fixes blindly.

- [x] **Step 5.3: Commit (only if README changes were made; otherwise skip)** — *no README changes were needed; skipped per instruction.*

Skip unless README was actually edited.

---

## Self-Review Notes

**Spec coverage:**
- ✅ SIGMET source + CLI (Task 2)
- ✅ AIRMET source + CLI with `--product` filter (Task 3)
- ✅ AFD model + source + CLI (Task 4)
- ✅ Winds aloft text-parse fix (Task 1)
- ✅ Text formatters for SIGMETs / AIRMETs / AFD (Tasks 2, 3, 4)
- ✅ Convenience API for `Skywatch.sigmets`, `.airmets`, `.afd(wfo)` (Tasks 2, 3, 4)
- ✅ TFRs explicitly out of scope (header note)

**Type/name consistency check:**
- `Models::Afd.from_nws` defined Task 4.4, called from `Sources::Afd#fetch` Task 4.9 ✅
- `Models::WindsAloft.decode(station_id:, altitude_ft:, encoded:)` already exists; Task 1.4 calls it with those exact kwargs ✅
- `format_altitude_band` introduced in Task 2.7, then `format_airmet_altitude` (separate helper) introduced in Task 3.7 — names differ on purpose since FL-style vs. raw-string altitude semantics differ ✅
- `Skywatch.sigmets` / `.airmets` / `.afd` all take their listed args (none / none / wfo) ✅

**Placeholder scan:** no TBDs, no "fill in", no "similar to" references — every step has actual code.
