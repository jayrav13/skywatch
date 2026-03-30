# frozen_string_literal: true

require_relative "lib/skywatch/version"

Gem::Specification.new do |spec|
  spec.name = "skywatch"
  spec.version = Skywatch::VERSION
  spec.authors = ["Jay Ravaliya"]
  spec.email = ["jayrav13@gmail.com"]

  spec.summary = "Aviation situational awareness toolkit"
  spec.description = "Real-time aviation weather, flight tracking, and situational awareness. " \
                     "Consolidates public FAA/NWS/ADS-B data into a unified CLI and Ruby API."
  spec.homepage = "https://github.com/jayrav13/skywatch"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/jayrav13/skywatch"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*", "exe/*", "LICENSE.txt"]
  spec.bindir = "exe"
  spec.executables = ["skywatch"]
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "faraday-retry", "~> 2.0"
  spec.add_dependency "rgeo", "~> 3.0"
  spec.add_dependency "rgeo-geojson", "~> 2.0"
  spec.add_dependency "thor", "~> 1.3"
end
