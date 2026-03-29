# frozen_string_literal: true

require_relative "lib/radar/version"

Gem::Specification.new do |spec|
  spec.name = "radar"
  spec.version = Radar::VERSION
  spec.authors = ["Jay Ravaliya"]
  spec.summary = "Flight tracking via OpenSky Network"
  spec.description = "Real-time flight tracking using the OpenSky Network API. Part of the skywatch aviation awareness system."
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.files = Dir["lib/**/*", "exe/*", "LICENSE.txt"]
  spec.bindir = "exe"
  spec.executables = ["radar"]

  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "faraday-retry", "~> 2.0"
  spec.add_dependency "thor", "~> 1.3"

  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rubocop", "~> 1.0"
  spec.add_development_dependency "webmock", "~> 3.0"
end
