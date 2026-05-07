module Carriers
  class FakeCarrier < Base
    SCRIPT = [
      { offset_hours: 0,  status: "label_created",     location: "Origin Facility", description: "Shipping label created" },
      { offset_hours: 4,  status: "picked_up",         location: "Origin Facility", description: "Carrier picked up package" },
      { offset_hours: 18, status: "in_transit",        location: "Sort Center",     description: "Package in transit" },
      { offset_hours: 36, status: "out_for_delivery",  location: "Local Facility",  description: "Out for delivery" },
      { offset_hours: 42, status: "delivered",         location: "Destination",     description: "Delivered to recipient" }
    ].freeze

    def fetch_tracking(tracking_number)
      with_error_boundary(tracking_number) do
        simulate_latency
        simulate_failure!

        events = build_events(tracking_number)
        status = events.last&.status || "pending"

        Response.success(events: events, status: status, raw_payload: { tracking_number: tracking_number })
      end
    end

    private

    def config
      Rails.configuration.carriers
    end

    def simulate_latency
      sleep(rand(config[:min_latency_ms]..config[:max_latency_ms]) / 1000.0)
    end

    def simulate_failure!
      roll = rand
      if roll < config[:timeout_rate]
        raise TimeoutError, "simulated network timeout"
      elsif roll < config[:timeout_rate] + config[:malformed_rate]
        raise MalformedResponseError, "simulated bad payload"
      end
    end

    def build_events(tracking_number)
      seed = Zlib.crc32(tracking_number)
      rng = Random.new(seed)
      cutoff = rng.rand(SCRIPT.size) + 1

      base_time = Time.current - 48.hours
      SCRIPT.first(cutoff).map do |step|
        Event.new(
          external_id: "#{tracking_number}-#{step[:status]}",
          status: step[:status],
          location: step[:location],
          description: step[:description],
          occurred_at: base_time + step[:offset_hours].hours
        )
      end
    end
  end
end
