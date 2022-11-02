require 'active_support/concern'
require 'active_support/lazy_load_hooks'

module FinderCache
  module Extension
    def self.included(klass)
      klass.extend ClassMethods
    end

    module ClassMethods
      def has_finder_cache(*args)
        options = args.extract_options!
        options.assert_valid_keys(:scope, :cache, :ttl, :expires_in, :finds_by)
        name = args[0] || options[:finds_by] || (FinderCache.config.finds_by == :primary_key ? self.primary_key : FinderCache.config.finds_by).to_sym || self.primary_key.to_sym
        return finder_caches[name] if finder_caches[name]

        finder_caches[name] = build_finder_cache(name.to_sym, options)
      end

      def build_finder_cache(name, options)
        return FinderCache.caches[self.name][name] if FinderCache.caches[self.name].key?(name)

        cache = FinderCache::Collection.new(self, **options)
        FinderCache.caches[self.name][name] = cache

        define_singleton_method "#{name}_finder_cache" do
          cache
        end

        cache
      end

      def finder_caches
        @finder_caches ||= {}
      end
    end
  end
end

ActiveSupport.on_load(:active_record) do
  include FinderCache::Extension
end
