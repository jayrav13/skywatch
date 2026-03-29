# frozen_string_literal: true

GEMS = Dir["*/Gemfile"].map { |f| File.dirname(f) }.sort.freeze

desc "Install dependencies for all gems"
task :install do
  GEMS.each do |gem_dir|
    puts "\n=== Installing #{gem_dir} ==="
    sh "cd #{gem_dir} && bundle install"
  end
end

desc "Run tests for all gems"
task :spec do
  failures = []
  GEMS.each do |gem_dir|
    puts "\n=== Testing #{gem_dir} ==="
    unless system("cd #{gem_dir} && bundle exec rspec")
      failures << gem_dir
    end
  end
  abort "\nFailed: #{failures.join(", ")}" unless failures.empty?
  puts "\nAll gems passed!"
end

desc "Run rubocop for all gems"
task :rubocop do
  failures = []
  GEMS.each do |gem_dir|
    puts "\n=== Linting #{gem_dir} ==="
    unless system("cd #{gem_dir} && bundle exec rubocop")
      failures << gem_dir
    end
  end
  abort "\nFailed: #{failures.join(", ")}" unless failures.empty?
  puts "\nAll gems passed!"
end

desc "Run all tests and linting"
task default: %i[spec rubocop]
