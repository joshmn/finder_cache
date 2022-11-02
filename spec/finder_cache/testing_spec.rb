require 'rails_helper'

RSpec.describe FinderCache::Testing do
  before do
    FinderCache.setup do |config|
      config.enabled = false
    end
  end

  after do
    FinderCache.setup do |config|
      config.enabled = true
    end
  end

  class FakeThing < ActiveRecord::Base
    self.table_name = :authors
  end

  it "disables the thing" do
    FakeThing.has_finder_cache
    FakeThing.id_finder_cache.load!

    expect { FakeThing.id_finder_cache.find(1) }.to make_database_queries
  end
end
