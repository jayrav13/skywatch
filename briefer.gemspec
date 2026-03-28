# frozen_string_literal: true

require_relative "lib/briefer/version"

Gem::Specification.new do |spec|
  spec.name = "briefer"
  spec.version = Briefer::VERSION
  spec.authors = ["Jay Ravaliya"]
  spec.email = ["jayrav13@gmail.com"]

  spec.summary = "FAA-standard preflight weather briefings for pilots and AI agents"
  spec.description = "Consolidates aviation weather data from free, public FAA/NWS sources " \
                     "into structured preflight briefings. Provides METAR, TAF, NOTAMs, " \
                     "TFRs, and go/no-go decisions via CLI and Ruby API."
  spec.homepage = "https://github.com/jayrav13/briefer"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/jayrav13/briefer"
  spec.metadata["changelog_uri"] = "https://github.com/jayrav13/briefer/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "faraday-retry", "~> 2.0"
  spec.add_dependency "thor", "~> 1.3"
end
