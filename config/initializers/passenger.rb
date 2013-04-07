if defined?(PhusionPassenger)
  PhusionPassenger.on_event(:starting_worker_process) do |forked|
    if forked
      Rails.cache.reconnect
      $redis = Redis.new db: 1, driver: :hiredis
    end
  end
end
