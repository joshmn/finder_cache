require "finder_cache/version"
require 'finder_cache/config'
require 'finder_cache/collection'
require 'finder_cache/extension'
require 'finder_cache/finder'
require 'finder_cache/testing'

module FinderCache
  def self.setup
    yield config
    initialize!
  end

  def self.config
    @config ||= Config.new
  end

  def self.caches
    @caches ||= Hash.new { |hash, key| hash[key] = {} }
  end

  def self.flush
    @caches = nil
  end

  def self.initialize!
    if config.enabled
      ::FinderCache::Collection.include ::FinderCache::Finder
    else
      ::FinderCache::Collection.include ::FinderCache::Testing
    end
  end
end
