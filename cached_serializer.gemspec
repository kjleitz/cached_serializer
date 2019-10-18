$:.push File.expand_path("lib", __dir__)

# Maintain your gem's version:
require "cached_serializer/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = "cached_serializer"
  spec.version     = CachedSerializer::VERSION
  spec.authors     = ["Keegan Leitz"]
  spec.email       = ["keegan@openbay.com"]
  spec.homepage    = "https://github.com/kjleitz/cached_serializer"
  spec.summary     = "A serializer for Rails models that prevents unnecessary lookups"
  spec.description = "A serializer for Rails models that prevents unnecessary lookups"
  spec.license     = "MIT"

  spec.files = Dir["{lib}/**/*", "Gemfile", "LICENSE", "MIT-LICENSE", "Rakefile", "README.md"]

  spec.add_dependency "rails", "~> 4.2.6"

  spec.add_development_dependency "sqlite3"
end
