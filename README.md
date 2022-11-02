# FinderCache

Cache your static-ish models, expire them appropriately, and retrieve them efficiently.

It's the fastest way. At least, that I know of.

## Why (short version)

There's a longer short-story at the end of this readme, but effectively we wanted to reduce the total number of connections made for relatively static objects in a very-high-throughput environment while maintaining parity across multiple independent services. A delightful, unintended consequence is that this happens to be extremely performant.

Do you need it? Unsure. Do you want it? Maybe.

It's like `IdentityCache` on steroids.

## Usage

The most basic example:

```ruby
class Business < ApplicationRecord 
  has_finder_cache # creates class method `id_finder_cache`
end

Business.id_finder_cache.find(1) # <Business id="1" name="One fine business">
```

Slightly more advanced:

```ruby
class Category < ApplicationRecord 
  has_finder_cache :slug, finds_by: :slug
end

Category.slug_finder_cache.find("funny") # <Category id="1" slug="funny" name="Funny stories">
```

And it gets much more configurable from there, but you get it.

## Installation

```bash
$ bundle add finder_cache
```

Have fun.

## Testing

Just set `enabled` to false in the configuration:

```ruby
FinderCache.setup do |config| 
  config.enabled = false 
end
```

And then you'll hit the database every time you invoke `#find` on a cache.

## Advanced usage

By default, the setup behavior works like this:

1. Query the model for records
2. Set the in-memory cache version to `Time.now`
3. Index the records by `:id` (`finds_by` in configuration)

When you perform an operation on a cache:

1. Check cache validity: is the cache's value is equal to our `cache_key` value? 
   a. throttle this check: only hit the cache every 60 seconds to not hammer the cache (`ttl`)
2. If not valid, rebuild the collection of records
3. Return the value of the collection based on the `key` sent
   a. FinderCache will try to cast the value sent appropriately
   b. if it's not found, FinderCache will try to query the model for it based on `finds_by` and `scope`); it will return this to the collection cache as well so if it tries to get looked up again, it won't be a cache miss

We do 3a to not hammer your cache. FinderCache was originally built to withstand 500 operations per second on a startup's pre-Series-A budget during a period where it was tough to fundraise. 

### Warming the cache 

Otherwise lazy-loaded:

```ruby
Category.id_finder_cache.load! 
```

Now that you know the behavior, let's customize it a bit:

### Disable the throttle and hammer your cache for whatever reason (default is `60.seconds`)

How long between calls do we check the cache. Set to `0` to disable the throttle mechanism which checks the version of your in-memory cache:

```ruby
class Category < ApplicationRecord 
  has_finder_cache ttl: 0.seconds
end
```

### Change the cache used (default is `Rails.cache`)

Must quack like `ActiveSupport::Cache::Store`.

```ruby
FinderCacheStore = ActiveSupport::Cache::RedisCacheStore.new(url: ENV['REDIS_FINDER_CACHE_URL'])

class Category < ApplicationRecord 
  has_finder_cache cache: FinderCacheStore # ur so nice to give it its own cache store :')
end
```

### Set the scope

```ruby
class Category < ApplicationRecord
  scope :active, -> { where(active: true) }
  
  has_finder_cache scope: :active 
end
```

### Set the cache key expiry (default is `1.hour`)

How long is the built collection of records is valid for.

```ruby
class Category < ApplicationRecord 
  has_finder_cache expires_in: 24.hours
end
```

### Use your own collections strategy (new-ish untested but should work fine with side-effects)

There are side-effects to this: the records won't be lazily-looked-up if they don't exist in the collection cache, and
we can't cast the index keys. 

```ruby
class Category < ApplicationRecord 
  has_finder_cache do 
     Category.all.index_by(&:something_cool)
  end
end
```

### All together now:

```ruby
FinderCacheStore = ActiveSupport::Cache::RedisCacheStore.new(url: ENV['REDIS_FINDER_CACHE_URL'])

class Category < ApplicationRecord
  scope :active, -> { where(active: true) }

  has_finder_cache cache: FinderCacheStore, scope: :active, ttl: 3.seconds, expires_in: 24.hours 
end
```

### Globals

Can be done in an initializer (defaults shown):

```ruby
FinderCache.setup do |config| 
  config.ttl = 60.seconds
  config.expires_in = 1.hour
  config.cache = Rails.cache
  config.finds_by = :id 
end
```

## Why

[Ignore story time](#Usage)

It was a bright and sunny day outside when the error Slack channel shit the bed: `ActiveRecord::ConnectionPool` was littered across my screen, even though we had a connection pool of 500. Same goes for our in-memory data structure Redis. Le sigh.

I spent some time looking into it and ultimately our background processor was chewing through jobs at a high rate — a good problem to have. I could have upgraded the RDBMS to the next tier but that was equal to a developer salary so no: this startup was runway-sensitive, I had to look for other options. Ultimately, I had to do one of the hardest thing in computer science: caching things.

I knew that whatever mechanism that would hold this cache had to be shared as close as realistically possible between our services (web server, background jobs), so I couldn't just memoize a collection of objects and index them by some key in a hash: if the cache expired in one process, it had to in the other. A pub-sub mechanism was explored but only explored since it relied on an external dependency.

After some discussion the team's gut instinct was to marshal the objects and put them into some data store and fetch the necessary record from there. That'd be okay for low-volume, but based on my decade-plus of experience creating bugs I knew that would be impractical for our setup.

## Benchmarks

It's hella-performant.

![Image](https://quickchart.io/chart?c=%7B%22type%22%3A%22bar%22%2C%22data%22%3A%7B%22labels%22%3A%5B%22finder_cache%22%2C%22memcached%22%2C%22redis%22%5D%2C%22datasets%22%3A%5B%7B%22backgroundColor%22%3A%22rgba%28255%2C+99%2C+132%2C+0.5%29%22%2C%22borderColor%22%3A%22rgb%28255%2C+99%2C+132%29%22%2C%22borderWidth%22%3A1%2C%22data%22%3A%5B1071562.292%2C13375.486%2C14240.507%5D%7D%5D%7D%2C%22options%22%3A%7B%22title%22%3A%7B%22display%22%3Atrue%2C%22text%22%3A%22Iterations+per+second+%28higher+is+better%29%22%7D%2C%22legend%22%3A%7B%22display%22%3Afalse%7D%2C%22plugins%22%3A%7B%22datalabels%22%3A%7B%22anchor%22%3A%22center%22%2C%22align%22%3A%22center%22%2C%22color%22%3A%22%23666%22%2C%22font%22%3A%7B%22weight%22%3A%22normal%22%7D%7D%7D%7D%7D)

If you're worried about memory footprint, it's extremely light.

More results can be found in [scripts/benchmark.csv](scripts/benchmark.csv).

## Contributing

Contribution directions go here.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
