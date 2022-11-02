$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'finder_cache'
require 'active_record'
require 'pry'
require 'db-query-matchers'

module Rails
  def self.cache
    @cache ||= ActiveSupport::Cache::MemoryStore.new
  end
end

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')

ActiveRecord::Schema.define do
  self.verbose = false

  create_table :authors, force: true do |t|
    t.boolean :published
    t.timestamps
  end
end

class Author < ActiveRecord::Base
end

class Post < ActiveRecord::Base
end

5.times { |i| Author.create!(published: i.odd?) }

#ActiveRecord::Base.logger = Logger.new(STDOUT)
