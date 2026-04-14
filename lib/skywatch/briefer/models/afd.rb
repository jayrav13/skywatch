# frozen_string_literal: true

require 'time'

module Skywatch
  module Briefer
    module Models
      class Afd
        attr_reader :wfo, :product_name, :issued_at, :text

        def self.from_nws(wfo, data)
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
