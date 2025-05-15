require_relative "version"

source "https://rubygems.org"
ruby Foobara::RedisCrudDriverVersion::MINIMUM_RUBY_VERSION

gemspec

# Development dependencies go here, others go in .gemspec instead

group :development, :test do
  gem "foobara-dotenv-loader"
  gem "pry"
  gem "pry-byebug"
  gem "rake"
  # Just requiring this to silence a deprecation warning coming from probably pry-byebug.
  # Can delete this once irb is required by that gem instead.
  gem "irb"
end

group :development do
  gem "foobara-rubocop-rules"
  gem "guard-rspec"
  gem "rubocop-rake"
  gem "rubocop-rspec"
end

group :test do
  gem "base64"
  gem "foobara-spec-helpers"
  gem "rspec"
  gem "rspec-its"
  gem "simplecov"
end
