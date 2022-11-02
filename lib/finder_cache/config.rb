module FinderCache
  class Config
    attr_accessor :ttl
    attr_accessor :expires_in
    attr_accessor :cache
    attr_accessor :finds_by
    attr_accessor :on_reset
    attr_accessor :now
    attr_accessor :enabled

    def initialize
      @ttl = 60.seconds
      @expires_in = 1.hour
      @cache = Rails.cache
      @finds_by = :primary_key
      @on_reset = nil
      @now = -> { Time.now.to_f }
      @enabled = true
    end

    def enabled?
      @enabled
    end

    def now=(val)
      raise ArgumentError, "config.now must be a block like `-> { Time.now.to_f }`" unless val.respond_to?(:call)

      super(val)
    end
  end
end
