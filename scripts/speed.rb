# frozen_string_literal: true
#GC.disable

require 'bundler/inline'

NUM_COLUMNS = 100
NUM_OBJECTS = 5

gemfile(true) do
  source "https://rubygems.org"
  gem "rails"
  gem "sqlite3"
  gem "redis"
  gem "benchmark-ips"
  gem "finder_cache", path: "./"
  gem 'memory_profiler'
  gem 'dalli'
end

require "active_record"
require "logger"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: "marshal.db")

ActiveRecord::Schema.define do
  self.verbose = false

  create_table :authors, force: true do |t|
    NUM_COLUMNS.times do |i|
      t.string "name_#{i}"
    end
    t.timestamps
  end
end


class TestApp < Rails::Application
  config.root = __dir__
end

Rails.application.initialize!

@stores = {
  memcached: ActiveSupport::Cache::MemCacheStore.new,
  redis: ActiveSupport::Cache::RedisCacheStore.new(driver: :hiredis),
  memory: ActiveSupport::Cache::MemoryStore.new,
  file: ActiveSupport::Cache::FileStore.new("cache")
}

CACHE = ActiveSupport::Cache::RedisCacheStore.new

class Author < ActiveRecord::Base
  has_finder_cache cache: CACHE, ttl: 10.second

end

authors = NUM_OBJECTS.times.map { |_| obj = {}; NUM_COLUMNS.times { |i| obj["name_#{i}"] = SecureRandom.hex }; obj }

Author.insert_all(authors)
Author.id_finder_cache.load!

bench = ->(x) {
  x.report("single") { Author.id_finder_cache.find(1) }
  x.report("multiple") { Author.id_finder_cache.find([1, 2, 3, 4, 5]) }
}

ips = Benchmark.ips do |x|
  x.warmup = 1
  x.time = 5
  bench.call(x)
  x.compare!
end
