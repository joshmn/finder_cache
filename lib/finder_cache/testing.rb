module FinderCache
  module Testing
    def find(keys)
      if keys.size == 1
        find_one(keys.first)
      else
        find_many(keys)
      end
    end

    private

    def find_one(key)
      scope.find_by(@finds_by => key)
    end

    def find_many(keys)
      scope.where(@finds_by => keys).load
    end
  end
end
