# frozen_string_literal: true

RSpec.describe Briefer::Formatters::Text do
  def metar_from_fixture(name)
    data = JSON.parse(File.read("spec/fixtures/metars/#{name}.json"))
    Briefer::Models::Metar.from_awc(data)
  end

  describe ".format_metar" do
    it "formats a standard METAR with station name and category" do
      metar = metar_from_fixture("kcdw")
      output = described_class.format_metar(metar)

      expect(output).to include("KCDW")
      expect(output).to include("Caldwell/Essex Cnty")
      expect(output).to include("VFR")
      expect(output).to include("METAR KCDW")
    end

    it "formats ceiling and wind from standard METAR" do
      metar = metar_from_fixture("kcdw")
      output = described_class.format_metar(metar)

      expect(output).to include("Ceiling: 7,000'")
      expect(output).to include("Wind: 330")
    end

    it "formats gusty winds" do
      metar = metar_from_fixture("kewr_gusty")
      output = described_class.format_metar(metar)

      expect(output).to include("G21")
    end

    it "shows no ceiling for clear skies" do
      metar = metar_from_fixture("clear_sky")
      output = described_class.format_metar(metar)

      expect(output).to include("Ceiling: -")
    end
  end

  describe ".format_category" do
    it "formats station with its flight category" do
      metar = metar_from_fixture("kcdw")
      output = described_class.format_category(metar)

      expect(output).to include("KCDW")
      expect(output).to include("VFR")
    end
  end
end
