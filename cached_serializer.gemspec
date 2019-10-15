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

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  spec.add_dependency "rails", "~> 4.2.6"

  spec.add_development_dependency "sqlite3"
end
