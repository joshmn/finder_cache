require 'rails_helper'

describe FinderCache::Collection do
  context 'when exists' do
    let!(:collection) { collection = described_class.new(Author); collection.load!; collection }
    let!(:id) { Author.first.id }

    it 'returns the object as it is in the db' do
      expect(collection.find(id)).to eq(Author.find(1))
    end

    it 'does not query' do
      expect { collection.find(id) }.to_not make_database_queries
    end

    it 'coerces the key' do
      expect { collection.find(id.to_s) }.to_not make_database_queries
    end
  end

  context 'missing' do
    let(:id) { -1 }

    it 'fires a query if the key does not exist' do
      collection = described_class.new(Author); collection.load!
      expect { collection.find(id) }.to make_database_queries
    end
  end

  context '#reset!' do
    let!(:id) { Author.first.id }
    it 'resets the stuff' do
      collection = described_class.new(Author); collection.load!
      expect { collection.reset!; collection.find(id) }.to make_database_queries(count: 1)
    end

    it 'calls the block if it exists' do
      FinderCache.config.on_reset = ->(_) { }

      collection = described_class.new(Author); collection.load!
      expect(FinderCache.config.on_reset).to receive(:call).with(collection).and_call_original
      collection.reset!
    end

    it 'does not call the block if it is nil' do
      FinderCache.config.on_reset = nil

      collection = described_class.new(Author); collection.load!
      expect(FinderCache.config.on_reset).to_not receive(:call)
      collection.reset!
    end
  end

  context '#load!' do
    it 'runs the query' do
      collection = described_class.new(Author)
      expect { collection.load! }.to make_database_queries
    end

    it 'runs the query and sets the version if an argument is passed' do
      collection = described_class.new(Author)
      collection.load!(5.seconds.ago)

      expect(collection.valid?).to be_falsey
    end

    it 'runs the query and is valid' do
      collection = described_class.new(Author)
      collection.load!

      expect( collection.valid?).to be_truthy
    end
  end

  context 'cache' do
    let(:collection) { collection = described_class.new(Author); collection.load!; collection }
    after do
      FinderCache.flush
    end

    it 'writes to the cache' do
      expect(Rails.cache.read(collection.cache_key)).to be_present
    end
  end

  context 'ttl' do
    let(:collection) { collection = described_class.new(Author); collection.load!(-1); collection }

    it 'calls the throttle if enough time has passed' do
      a = collection.instance_variable_get(:@last_check)
      collection.find(1)

      expect { collection.find(1) }.to change { collection.instance_variable_get(:@last_check) }
      #      expect { collection.find(1) }.to make_database_queries match: /SELECT "authors".* FROM "authors"/
    end
  end

  context 'find_many' do
    let(:collection) { collection = described_class.new(Author); collection.load!; collection }

    it 'returns multiple' do
      ids = Author.all.pluck(:id)

      expect(collection.find(ids).size).to eq(ids.size)
    end
  end
end
