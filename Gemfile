require_relative "version"

source "https://rubygems.org"
ruby Foobara::RedisCrudDriverVersion::MINIMUM_RUBY_VERSION

gemspec

# gem "foobara", path: "../foobara"

# Development dependencies go here, others go in .gemspec instead

group :development, :test do
  gem "foobara-dotenv-loader", "< 2.0.0"
  gem "pry"
  gem "pry-byebug"
  gem "rake"
  # Just requiring this to silence a deprecation warning coming from probably pry-byebug.
  # Can delete this once irb is required by that gem instead.
  gem "irb"
end

group :development do
  gem "foobara-rubocop-rules", ">= 1.0.0"
  gem "guard-rspec"
  gem "rubocop-rake"
  gem "rubocop-rspec"
end

group :test do
  gem "base64"
  gem "foobara-crud-driver-spec-helpers", "< 2.0.0" # , path: "../crud-driver-spec-helpers"
  gem "foobara-spec-helpers", "< 2.0.0"
  gem "rspec"
  gem "rspec-its"
  gem "simplecov"
end
