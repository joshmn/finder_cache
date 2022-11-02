require 'finder_cache/finder'

module FinderCache
  class Collection
    CACHE_KEY_PREFIX = :finder_cache
    include ::FinderCache::Finder

    attr_reader :klass, :scope, :finds_by, :cache_key

    def initialize(klass,
                   finds_by: nil,
                   scope: :all,
                   cache: FinderCache.config.cache,
                   ttl: FinderCache.config.ttl,
                   expires_in: FinderCache.config.expires_in,
                   &block
                   )
      @klass = klass
      @scope = scope
      @cache = cache
      @ttl = ttl
      @cache_key = "#{CACHE_KEY_PREFIX}:#{@klass}:#{@finds_by}"
      @expires_in = expires_in
      @last_check = 0
      @block = block
      if block_collection? && finds_by
        raise ArgumentError, "can't use finds_by with a block collection."
      elsif block_collection?
        @key_type = @klass.columns_hash[key_type].try(:type)
      else
        @finds_by = (finds_by || (::FinderCache.config.finds_by == :primary_key ? klass.primary_key.to_sym : ::FindsCache.config.finds_by) || klass.primary_key).to_sym
        column_type = @klass.columns_hash[@finds_by.to_s].try(:type)
        @key_type = ActiveModel::Type.lookup(column_type)
      end
    end

    def reset!
      @collection = nil
      @loaded = false
      @version = nil
      @last_check = 0

      if ::FinderCache.config.on_reset
        ::FinderCache.config.on_reset.call(self)
      end

      true
    end

    def loaded?
      @loaded
    end

    def load!(version = nil)
      reset!
      load_collection

      if version
        @version = version.to_f
      end

      true
    end

    # only hit cache every @ttl
    def valid?
      return false unless loaded?
      return false unless @version
      return true if @version >= now

      throttled do
        @cache.read(@cache_key) == @version
      end
    end

    private

    def collection
      return @collection if @collection

      load_collection
    end

    def load_collection
      if block_collection?
        @collection = @block.call
      else
        items = scope
        @collection = items.index_by(&@finds_by)
      end
      @version = now
      @cache.write(@cache_key, @version, expires_in: @expires_in)
      @loaded = true
      @collection
    end

    def scope
      @klass.public_send(@scope)
    end

    def now
      ::FinderCache.config.now.call
    end

    def throttled(&block)
      if now > (@last_check + @ttl.to_i)
        @last_check = now

        return block.call
      end

      true # do nothing
    end

    def normalize_key(key)
      begin
        return @key_type.cast(key)
      rescue ArgumentError => e
        Rails.logger.info("Unable to cast #{key.inspect}: #{e.inspect}")
        return key
      end
    end

    def block_collection?
      @block
    end
  end
end
