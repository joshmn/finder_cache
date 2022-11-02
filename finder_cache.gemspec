require_relative "lib/finder_cache/version"

Gem::Specification.new do |spec|
  spec.name        = "finder_cache"
  spec.version     = FinderCache::VERSION
  spec.authors     = ["joshmn"]
  spec.email       = ["git@josh.mn"]
  spec.homepage    = "https://github.com/joshmn/finder_cache"
  spec.summary     = "Cache your static-ish models, expire them appropriately, and retrieve them efficiently."
  spec.description = "Cache your static-ish models, expire them appropriately, and retrieve them efficiently."
  spec.license     = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = spec.homepage

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 5"

  spec.add_development_dependency 'factory_bot_rails'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'db-query-matchers'
  spec.add_development_dependency 'rspec-rails'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'sqlite3'
end
