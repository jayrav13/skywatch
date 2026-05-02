# frozen_string_literal: true

require 'time'

module Skywatch
  module Brief
    module Analysis
      class Composer # rubocop:disable Metrics/ClassLength
        ADVERSE_RADIUS_NM = 100
        STORM_REPORT_LOOKBACK_HOURS = 6
        NEAR_STATION_THRESHOLD_NM = 25

        # rubocop:disable Metrics/ParameterLists
        def initialize(metar_source: Skywatch::Briefer::Sources::Metar.new,
                       taf_source: Skywatch::Briefer::Sources::Taf.new,
                       pirep_source: Skywatch::Briefer::Sources::Pirep.new,
                       winds_source: Skywatch::Briefer::Sources::WindsAloft.new,
                       sigmet_source: Skywatch::Briefer::Sources::Sigmet.new,
                       airmet_source: Skywatch::Briefer::Sources::Airmet.new,
                       afd_source: Skywatch::Briefer::Sources::Afd.new,
                       alerts_source: Skywatch::Nimbus::Sources::Alerts.new,
                       storm_source: Skywatch::Nimbus::Sources::StormReport.new,
                       smoke_source: Skywatch::Nimbus::Sources::Smoke.new)
          @metar_source = metar_source
          @taf_source = taf_source
          @pirep_source = pirep_source
          @winds_source = winds_source
          @sigmet_source = sigmet_source
          @airmet_source = airmet_source
          @afd_source = afd_source
          @alerts_source = alerts_source
          @storm_source = storm_source
          @smoke_source = smoke_source
        end
        # rubocop:enable Metrics/ParameterLists

        def compose(airport: nil, at: nil)
          case [airport.nil?, at.nil?]
          when [false, true] then compose_for_airport(airport)
          when [true, false] then compose_for_coords(*at)
          else raise ArgumentError, 'must specify exactly one of airport: or at:'
          end
        end

        private

        def compose_for_airport(airport)
          metar = fetch_metar_or_raise(airport)
          lat, lon = AirportLocator.coordinates_from_metar(metar)
          build_brief(airport_id: airport.upcase, requested_lat: lat, requested_lon: lon,
                      metar: metar, note: nil)
        end

        def compose_for_coords(req_lat, req_lon)
          metar = @metar_source.fetch_nearest(lat: req_lat, lon: req_lon)
          raise Skywatch::Error, "no METAR reporting station near #{req_lat},#{req_lon}" if metar.nil?

          distance = Skywatch::Radar::Analysis::Proximity.distance_nm(
            req_lat, req_lon, metar.latitude, metar.longitude
          )
          build_brief(airport_id: metar.station_id, requested_lat: req_lat, requested_lon: req_lon,
                      metar: metar, note: nearest_station_note(metar.station_id, distance))
        end

        def nearest_station_note(station_id, distance_nm)
          if distance_nm > NEAR_STATION_THRESHOLD_NM
            "WARNING: nearest reporting station #{station_id} is #{distance_nm} nm " \
              'from the requested point — local conditions may differ significantly'
          else
            "data sourced from nearest reporting station #{station_id} " \
              "(#{distance_nm} nm from requested point)"
          end
        end

        # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
        def build_brief(airport_id:, requested_lat:, requested_lon:, metar:, note:)
          wfo = wrap_wfo(requested_lat, requested_lon)
          pirep_attempt = attempt { @pirep_source.fetch(airport_id, radius_nm: ADVERSE_RADIUS_NM) }
          partitioned = AdverseFilter.partition_pireps(pirep_attempt[:value] || [])

          Models::Brief.new(
            airport: airport_id,
            coordinates: [requested_lat, requested_lon],
            wfo: wfo,
            fetched_at: Time.now.utc,
            adverse_conditions: build_adverse(
              lat: requested_lat, lon: requested_lon,
              urgent_pireps: partitioned[:urgent], pirep_attempt: pirep_attempt
            ),
            vfr_not_recommended: build_vfr(metar),
            current_conditions: build_current(metar: metar, pirep_attempt: pirep_attempt,
                                              informational: partitioned[:informational]),
            destination_forecast: wrap('TAF') { build_destination(airport_id) },
            winds_aloft: wrap('winds aloft') { build_winds(airport_id) },
            afd: wfo.nil? ? unavailable_afd_for_no_wfo : wrap('AFD') { build_afd(wfo) },
            note: note
          )
        end
        # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

        def fetch_metar_or_raise(airport)
          metars = @metar_source.fetch(airport)
          raise Skywatch::Error, "no METAR for #{airport.upcase}" if metars.empty?

          metars.first
        end

        def wrap_wfo(lat, lon)
          AirportLocator.wfo_for(lat, lon)
        rescue StandardError
          nil
        end

        def unavailable_afd_for_no_wfo
          { available: false, reason: 'fetch failed: WFO lookup failed' }
        end

        def attempt
          { value: yield, error: nil }
        rescue StandardError => e
          { value: nil, error: "#{e.class}: #{e.message}" }
        end

        def wrap(_label)
          yield
        rescue StandardError => e
          { available: false, reason: "fetch failed: #{e.class}: #{e.message}" }
        end

        # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        def build_adverse(lat:, lon:, urgent_pireps:, pirep_attempt:)
          sigmet_attempt = attempt { @sigmet_source.fetch.select { |s| AdverseFilter.covers?(s, lat, lon) } }
          airmet_attempt = attempt { @airmet_source.fetch.select { |a| AdverseFilter.covers?(a, lat, lon) } }
          alerts_attempt = attempt { @alerts_source.fetch(at: [lat, lon]) }
          storm_attempt = attempt do
            recent = recent_storms(@storm_source.fetch)
            AdverseFilter.within(recent, lat: lat, lon: lon, radius_nm: ADVERSE_RADIUS_NM)
          end
          smoke_attempt = attempt { @smoke_source.fetch(at: [lat, lon]) }

          attempts = {
            'sigmet' => sigmet_attempt, 'airmet' => airmet_attempt,
            'pirep' => pirep_attempt, 'convective_alert' => alerts_attempt,
            'storm_report' => storm_attempt, 'smoke' => smoke_attempt
          }
          partial_failures = attempts.reject { |_, a| a[:error].nil? }
                                     .map { |s, a| { source: s, reason: a[:error] } }

          if partial_failures.size == attempts.size
            return { available: false,
                     reason: "all adverse sources failed: #{partial_failures.map { |f| f[:source] }.join(', ')}" }
          end

          items = []
          items.concat((sigmet_attempt[:value] || []).map { |s| { kind: 'sigmet' }.merge(s.to_h) })
          items.concat((airmet_attempt[:value] || []).map { |a| { kind: 'airmet' }.merge(a.to_h) })
          items.concat(urgent_pireps.map { |p| { kind: 'pirep' }.merge(p.to_h) })
          items.concat((alerts_attempt[:value] || []).map { |a| { kind: 'convective_alert' }.merge(a.to_h) })
          items.concat((storm_attempt[:value] || []).map { |s| { kind: 'storm_report' }.merge(s.to_h) })
          items.concat((smoke_attempt[:value] || []).map { |s| { kind: 'smoke' }.merge(s.to_h) })

          { available: true, items: items, partial_failures: partial_failures }
        end
        # rubocop:enable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

        def recent_storms(storms)
          cutoff = Time.now.utc - (STORM_REPORT_LOOKBACK_HOURS * 3600)
          storms.select { |s| s.time && s.time >= cutoff }
        end

        def build_vfr(metar) # rubocop:disable Metrics/MethodLength
          case metar.flight_category
          when :lifr, :ifr
            { available: true, vfr_not_recommended: true,
              category: metar.flight_category.to_s.upcase, explanation: explanation_for(metar) }
          when :mvfr
            { available: true, vfr_not_recommended: false,
              category: 'MVFR', explanation: "marginal — #{explanation_for(metar)}" }
          else
            { available: true, vfr_not_recommended: false,
              category: 'VFR', explanation: 'VFR conditions' }
          end
        end

        def explanation_for(metar)
          parts = []
          parts << "ceiling #{metar.ceiling_ft} ft" if metar.ceiling_ft
          parts << "vis #{metar.visibility_sm} SM" if metar.visibility_sm
          parts.empty? ? 'see METAR' : parts.join(', ')
        end

        def build_current(metar:, pirep_attempt:, informational:)
          if pirep_attempt[:error]
            { available: true, metar: metar.to_h, pireps: [],
              partial_failure: { source: 'pirep', reason: pirep_attempt[:error] } }
          else
            { available: true, metar: metar.to_h, pireps: informational.map(&:to_h) }
          end
        end

        def build_destination(airport)
          tafs = @taf_source.fetch(airport)
          if tafs.empty?
            { available: false, reason: "no TAF for #{airport.upcase}" }
          else
            { available: true, taf: tafs.first.to_h }
          end
        end

        def build_winds(airport)
          forecasts = @winds_source.fetch(airport)
          if forecasts.empty?
            { available: false, reason: "no winds aloft for #{airport.upcase}" }
          else
            { available: true, station: airport.upcase, forecasts: forecasts.map(&:to_h) }
          end
        end

        def build_afd(wfo)
          afd = @afd_source.fetch(wfo)
          { available: true, wfo: afd.wfo, text: afd.text, issued_at: afd.issued_at&.iso8601 }
        end
      end
    end
  end
end
