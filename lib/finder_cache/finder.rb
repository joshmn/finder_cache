module FinderCache
  module Finder
    def find(keys)
      reset! unless valid?

      keys = Array(keys).map { |key| normalize_key(key) }

      if keys.size == 1
        find_one(keys.first)
      else
        find_many(keys)
      end
    end

    private

    def find_one(key)
      return collection[key] if collection.key?(key)

      collection[key] ||= scope.find_by(@finds_by => key)
    end

    def find_many(keys)
      missing = []
      results = []

      keys.each do |key|
        if collection.key?(key)
          results << collection[key]
        else
          missing << key
        end
      end

      if missing.any?
        scope.where(@finds_by => missing).each do |obj|
          collection[normalize_key(obj.public_send(finds_by))] = obj
          results << obj
        end
      end

      results
    end
  end
end
