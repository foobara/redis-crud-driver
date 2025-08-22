require_relative "version"

Gem::Specification.new do |spec|
  spec.name = "foobara-redis-crud-driver"
  spec.version = Foobara::RedisCrudDriverVersion::VERSION
  spec.authors = ["Miles Georgi"]
  spec.email = ["azimux@gmail.com"]

  spec.summary = "Provides support for entity CRUD in Redis for Foobara"
  spec.description = spec.summary
  spec.homepage = "https://github.com/foobara/redis-crud-driver"
  spec.license = "MPL-2.0"
  spec.required_ruby_version = Foobara::RedisCrudDriverVersion::MINIMUM_RUBY_VERSION

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir[
    "lib/**/*",
    "src/**/*",
    "LICENSE*.txt",
    "README.md",
    "CHANGELOG.md",
    ".ruby-version"
  ]

  spec.require_paths = ["src"]

  spec.add_dependency "foobara", ">= 0.1.1", "< 2.0.0"
  spec.add_dependency "redis"

  spec.metadata["rubygems_mfa_required"] = "true"
end
