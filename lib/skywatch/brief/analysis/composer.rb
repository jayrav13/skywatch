# frozen_string_literal: true

require 'time'

module Skywatch
  module Brief
    module Analysis
      class Composer # rubocop:disable Metrics/ClassLength
        ADVERSE_RADIUS_NM = 100
        STORM_REPORT_LOOKBACK_HOURS = 6

        # rubocop:disable Metrics/ParameterLists
        def initialize(metar_source: Skywatch::Briefer::Sources::Metar.new,
                       taf_source: Skywatch::Briefer::Sources::Taf.new,
                       pirep_source: Skywatch::Briefer::Sources::Pirep.new,
                       winds_source: Skywatch::Briefer::Sources::WindsAloft.new,
                       sigmet_source: Skywatch::Briefer::Sources::Sigmet.new,
                       airmet_source: Skywatch::Briefer::Sources::Airmet.new,
                       afd_source: Skywatch::Briefer::Sources::Afd.new,
                       alerts_source: Skywatch::Nimbus::Sources::Alerts.new,
                       storm_source: Skywatch::Nimbus::Sources::StormReport.new)
          @metar_source = metar_source
          @taf_source = taf_source
          @pirep_source = pirep_source
          @winds_source = winds_source
          @sigmet_source = sigmet_source
          @airmet_source = airmet_source
          @afd_source = afd_source
          @alerts_source = alerts_source
          @storm_source = storm_source
        end
        # rubocop:enable Metrics/ParameterLists

        def compose(airport:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
          metar = fetch_metar_or_raise(airport)
          lat, lon = AirportLocator.coordinates_from_metar(metar)
          wfo = AirportLocator.wfo_for(lat, lon)

          pireps = @pirep_source.fetch(airport, radius_nm: ADVERSE_RADIUS_NM)
          partitioned = AdverseFilter.partition_pireps(pireps)

          Models::Brief.new(
            airport: airport.upcase,
            coordinates: [lat, lon],
            wfo: wfo,
            fetched_at: Time.now.utc,
            adverse_conditions: build_adverse(lat: lat, lon: lon, urgent_pireps: partitioned[:urgent]),
            vfr_not_recommended: build_vfr(metar),
            current_conditions: build_current(metar: metar, pireps: partitioned[:informational]),
            destination_forecast: build_destination(airport),
            winds_aloft: build_winds(airport),
            afd: build_afd(wfo)
          )
        end

        private

        def fetch_metar_or_raise(airport)
          metars = @metar_source.fetch(airport)
          raise Skywatch::Error, "no METAR for #{airport.upcase}" if metars.empty?

          metars.first
        end

        def build_adverse(lat:, lon:, urgent_pireps:)
          sigmets = @sigmet_source.fetch.select { |s| AdverseFilter.covers?(s, lat, lon) }
          airmets = @airmet_source.fetch.select { |a| AdverseFilter.covers?(a, lat, lon) }
          alerts = @alerts_source.fetch(at: [lat, lon])
          all_storms = @storm_source.fetch
          recent = recent_storms(all_storms)
          near_storms = AdverseFilter.within(recent, lat: lat, lon: lon, radius_nm: ADVERSE_RADIUS_NM)

          items = adverse_items(sigmets, airmets, urgent_pireps, alerts, near_storms)
          { available: true, items: items, partial_failures: [] }
        end

        def adverse_items(sigmets, airmets, urgent_pireps, alerts, near_storms) # rubocop:disable Metrics/AbcSize
          items = []
          items.concat(sigmets.map { |s| { kind: 'sigmet' }.merge(s.to_h) })
          items.concat(airmets.map { |a| { kind: 'airmet' }.merge(a.to_h) })
          items.concat(urgent_pireps.map { |p| { kind: 'pirep' }.merge(p.to_h) })
          items.concat(alerts.map { |a| { kind: 'convective_alert' }.merge(a.to_h) })
          items.concat(near_storms.map { |s| { kind: 'storm_report' }.merge(s.to_h) })
          items
        end

        def recent_storms(storms)
          cutoff = Time.now.utc - (STORM_REPORT_LOOKBACK_HOURS * 3600)
          storms.select { |s| s.time && s.time >= cutoff }
        end

        def build_vfr(metar) # rubocop:disable Metrics/MethodLength
          category = metar.flight_category
          case category
          when :lifr, :ifr
            { available: true, vfr_not_recommended: true, category: category.to_s.upcase,
              explanation: explanation_for(metar) }
          when :mvfr
            { available: true, vfr_not_recommended: false, category: 'MVFR',
              explanation: "marginal — #{explanation_for(metar)}" }
          else
            { available: true, vfr_not_recommended: false, category: 'VFR',
              explanation: 'VFR conditions' }
          end
        end

        def explanation_for(metar)
          parts = []
          parts << "ceiling #{metar.ceiling_ft} ft" if metar.ceiling_ft
          parts << "vis #{metar.visibility_sm} SM" if metar.visibility_sm
          parts.empty? ? 'see METAR' : parts.join(', ')
        end

        def build_current(metar:, pireps:)
          { available: true, metar: metar.to_h, pireps: pireps.map(&:to_h) }
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
