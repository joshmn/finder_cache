require 'rails_helper'

RSpec.describe FinderCache::Extension do
  it "hooks into ActiveRecord::Base" do
    expect(ActiveRecord::Base).to respond_to(:has_finder_cache)
  end

  class FakeThing < ActiveRecord::Base
    self.table_name = :authors
    scope :published, -> { where(published: true) }
  end

  context 'FakeThing' do
    before do
      FakeThing.has_finder_cache
    end

    it 'has a cache method' do
      expect(FakeThing).to respond_to(:id_finder_cache)
    end

    it 'has a cache' do
      expect(FakeThing.id_finder_cache).to eq(FinderCache.caches[FakeThing.name][:id])
    end
  end

  context 'options' do
    context 'scope' do
      FakeThing.has_finder_cache :published, scope: :published

      it 'sets cool scope' do
        expect(FakeThing.published_finder_cache.instance_variable_get(:@scope)).to eq(:published)
      end
    end

    context 'ttl' do
      FakeThing.has_finder_cache :ttl, ttl: 11.seconds

      it 'sets cool scope' do
        expect(FakeThing.ttl_finder_cache.instance_variable_get(:@ttl)).to eq(11.seconds)
      end
    end

    context 'expires_in' do
      FakeThing.has_finder_cache :expires_in, expires_in: 11.seconds

      it 'sets expires_in' do
        expect(FakeThing.expires_in_finder_cache.instance_variable_get(:@expires_in)).to eq(11.seconds)
      end
    end

    context 'finds_by' do
      FakeThing.has_finder_cache :finds_by, finds_by: :updated_at

      it 'sets finds_by' do
        expect(FakeThing.finds_by_finder_cache.instance_variable_get(:@finds_by)).to eq(:updated_at)
      end
    end
  end
end
