# frozen_string_literal: true
#GC.disable

NUM_COLUMNS = 15
NUM_OBJECTS = 100
MULTIPLE = false

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"
  gem "rails"
  gem "sqlite3"
  gem "redis"
  gem "benchmark-ips"
  gem "finder_cache", path: "./"
  gem 'dalli'
  gem 'benchmark-memory'
  gem 'pry'
  gem 'memory_profiler'
  gem 'hiredis'
  gem 'identity_cache'
end

require "active_record"
require "logger"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: "marshal.db")
#ActiveRecord::Base.logger = Logger.new(STDOUT)

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
  # memory: ActiveSupport::Cache::MemoryStore.new,
  # file: ActiveSupport::Cache::FileStore.new("cache")
}
CACHE = ActiveSupport::Cache::RedisCacheStore.new
IdentityCache.cache_backend = ActiveSupport::Cache::MemCacheStore.new

class Author < ActiveRecord::Base
  include IdentityCache

  has_finder_cache cache: CACHE, ttl: 1.second

  def self.find_by_cached_id(store, id)
    store.read(:authors)[id]
  end

  def self.find_by_cached_ids(store, ids)
    ids.map { |id| store.read(:authors)[id] }
  end

  def self.find_by_individual_id(store, id)
    store.read("author-#{id}")
  end

  def self.find_by_individual_ids(store, ids)
    ids.map { |id| store.read("author-#{id}") }
  end
end

authors = NUM_OBJECTS.times.map { |_| obj = {}; NUM_COLUMNS.times { |i| obj["name_#{i}"] = SecureRandom.hex }; obj }

Author.insert_all(authors)
Author.id_finder_cache.load!
Author.fetch(1)

@stores.each do |_, store|
  Author.all.each do |author|
    store.write("author-#{author.id}", author)
  end
end

bench = ->(x) {
  if MULTIPLE
    x.report("finder_cache multiple") { Author.id_finder_cache.find([1, 2]) }
  else
    x.report("finder_cache") { Author.id_finder_cache.find(1) }
    x.report("identity_cache") { Author.fetch(1) }
  end
  if MULTIPLE
    @stores.each do |name, store|
      x.report("#{name} multiple") { Author.find_by_individual_ids(store, [1, 2]) }
    end
  else
    @stores.each do |name, store|
      x.report(name) { Author.find_by_individual_id(store, 1) }
    end
  end

}
ips = Benchmark.ips do |x|
  x.warmup = 1
  x.time = 5
  bench.call(x)
  x.compare!
end
# @prof = MemoryProfiler.report { Author.id_finder_cache.find(1).id }

mem = Benchmark.memory do |x|
  bench.call(x)

  x.compare!
end

results = {}
require 'csv'

report = CSV.generate(headers: true) do |csv|
  csv << ["Strategy", "IPS", "Memsize (allocated)", "Memsize (retained)", "Objects (retained)", "Objects (retained)"]
  ips.data.each do |result|
    mem_data = mem.as_json['comparison']['entries'].detect { |entry| entry['label'] == result[:name].to_s }
    results[result[:name]] = {
      ips: result[:central_tendency].round(3),
      memory: mem_data['measurement'].index_by { |measurement| measurement['type'] }
    }

    line = results[result[:name]]
    csv << [
      result[:name],
      line[:ips],
      line[:memory]['memsize']['allocated'],
      line[:memory]['memsize']['retained'],
      line[:memory]['objects']['allocated'],
      line[:memory]['objects']['retained'],
    ]

  end
end

File.write("scripts/benchmark.csv", report)

url = {
  type: 'bar',
  data: {
    labels: results.keys,
    datasets: [
      {
        backgroundColor: 'rgba(255, 99, 132, 0.5)',
        borderColor: 'rgb(255, 99, 132)',
        borderWidth: 1,
        data: results.map { |k,v| v[:ips] },
      },
    ],
  },
  options: {
    title: {
      display: true,
      text: 'Iterations per second (higher is better)',
    },
    legend: { display: false },
    plugins: {
      datalabels: {
        anchor: 'center',
        align: 'center',
        color: '#666',
        font: {
          weight: 'normal',
        },
      },
    },
  },
}

base = "https://quickchart.io/chart"
ips = base + "?c=#{URI.encode_www_form_component(url.to_json)}"

puts "IPS chart:"
puts ips

url = {
  type: 'bar',
  data: {
    labels: results.keys,
    datasets: [
      {
        backgroundColor: 'rgba(255, 99, 132, 0.5)',
        borderColor: 'rgb(255, 99, 132)',
        borderWidth: 1,
        data: results.map { |k,v| v[:memory]['memsize']['allocated'] },
      },
    ],
  },
  options: {
    title: {
      display: true,
      text: 'Memory footprint in bytes (lower is better)',
    },
    legend: { display: false },
    plugins: {
      datalabels: {
        anchor: 'center',
        align: 'center',
        color: '#666',
        font: {
          weight: 'normal',
        },
      },
    },
  },
}

base = "https://quickchart.io/chart"
mem = base + "?c=#{URI.encode_www_form_component(url.to_json)}"

puts "Memory chart:"
puts mem

`rm -rf cache`
`rm marshal.db`
`rm -rf scripts/log`
