# frozen_string_literal: true

module Briefer
  module Analysis
    module FlightCategory
      CATEGORIES = %i[lifr ifr mvfr vfr].freeze

      def self.classify(ceiling_ft:, visibility_sm:)
        ceiling_cat = classify_ceiling(ceiling_ft)
        visibility_cat = classify_visibility(visibility_sm)

        # Return the worse (lower index) category
        worse_index = [CATEGORIES.index(ceiling_cat), CATEGORIES.index(visibility_cat)].min
        CATEGORIES[worse_index]
      end

      def self.classify_ceiling(ceiling_ft)
        return :vfr if ceiling_ft.nil?

        if ceiling_ft < 500 then :lifr
        elsif ceiling_ft < 1000 then :ifr
        elsif ceiling_ft <= 3000 then :mvfr
        else :vfr
        end
      end

      def self.classify_visibility(visibility_sm)
        if visibility_sm < 1 then :lifr
        elsif visibility_sm < 3 then :ifr
        elsif visibility_sm <= 5 then :mvfr
        else :vfr
        end
      end

      private_class_method :classify_ceiling, :classify_visibility
    end
  end
end
