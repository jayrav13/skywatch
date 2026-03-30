# frozen_string_literal: true

RSpec.describe Skywatch::Briefer::Analysis::FlightCategory do
  describe ".classify" do
    # VFR: ceiling > 3000 AND visibility > 5
    it "returns :vfr for clear skies and good visibility" do
      expect(described_class.classify(ceiling_ft: 5000, visibility_sm: 10)).to eq(:vfr)
    end

    it "returns :vfr for nil ceiling (unlimited) and good visibility" do
      expect(described_class.classify(ceiling_ft: nil, visibility_sm: 10)).to eq(:vfr)
    end

    # MVFR: ceiling 1000-3000 OR visibility 3-5
    it "returns :mvfr for ceiling at exactly 3000" do
      expect(described_class.classify(ceiling_ft: 3000, visibility_sm: 10)).to eq(:mvfr)
    end

    it "returns :mvfr for visibility at exactly 5" do
      expect(described_class.classify(ceiling_ft: 5000, visibility_sm: 5)).to eq(:mvfr)
    end

    it "returns :mvfr for ceiling 1000 and good visibility" do
      expect(described_class.classify(ceiling_ft: 1000, visibility_sm: 10)).to eq(:mvfr)
    end

    it "returns :mvfr for visibility 3 and high ceiling" do
      expect(described_class.classify(ceiling_ft: 5000, visibility_sm: 3)).to eq(:mvfr)
    end

    # IFR: ceiling 500-999 OR visibility 1-<3
    it "returns :ifr for ceiling at exactly 999" do
      expect(described_class.classify(ceiling_ft: 999, visibility_sm: 10)).to eq(:ifr)
    end

    it "returns :ifr for ceiling at exactly 500" do
      expect(described_class.classify(ceiling_ft: 500, visibility_sm: 10)).to eq(:ifr)
    end

    it "returns :ifr for visibility at 2" do
      expect(described_class.classify(ceiling_ft: 5000, visibility_sm: 2.5)).to eq(:ifr)
    end

    it "returns :ifr for visibility at 1" do
      expect(described_class.classify(ceiling_ft: 5000, visibility_sm: 1)).to eq(:ifr)
    end

    # LIFR: ceiling < 500 OR visibility < 1
    it "returns :lifr for ceiling at 499" do
      expect(described_class.classify(ceiling_ft: 499, visibility_sm: 10)).to eq(:lifr)
    end

    it "returns :lifr for ceiling at 0" do
      expect(described_class.classify(ceiling_ft: 0, visibility_sm: 10)).to eq(:lifr)
    end

    it "returns :lifr for visibility at 0.5" do
      expect(described_class.classify(ceiling_ft: 5000, visibility_sm: 0.5)).to eq(:lifr)
    end

    it "returns :lifr for visibility at 0" do
      expect(described_class.classify(ceiling_ft: 5000, visibility_sm: 0)).to eq(:lifr)
    end

    # Lowest condition wins
    it "uses the lower category when ceiling and visibility differ" do
      # VFR ceiling but IFR visibility
      expect(described_class.classify(ceiling_ft: 5000, visibility_sm: 2)).to eq(:ifr)
    end

    it "uses the lower category when visibility is worse" do
      # MVFR ceiling but LIFR visibility
      expect(described_class.classify(ceiling_ft: 2000, visibility_sm: 0.5)).to eq(:lifr)
    end

    # Nil ceiling + low vis
    it "returns :lifr for nil ceiling and very low visibility" do
      expect(described_class.classify(ceiling_ft: nil, visibility_sm: 0.25)).to eq(:lifr)
    end
  end
end
