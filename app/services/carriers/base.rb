module Carriers
  class Base
    class CarrierError < StandardError; end
    class TimeoutError < CarrierError; end
    class MalformedResponseError < CarrierError; end

    DEFAULT_TIMEOUT = 5

    def fetch_tracking(tracking_number)
      raise NotImplementedError, "#{self.class}#fetch_tracking must be implemented"
    end

    protected
    
    def with_error_boundary(tracking_number)
      yield
    rescue TimeoutError => e
      Rails.logger.warn("[Carriers] timeout fetching #{tracking_number}: #{e.message}")
      Response.failed(error: "Carrier timed out: #{e.message}")
    rescue MalformedResponseError => e
      Rails.logger.error("[Carriers] malformed response for #{tracking_number}: #{e.message}")
      Response.failed(error: "Carrier returned malformed data: #{e.message}")
    rescue StandardError => e
      Rails.logger.error("[Carriers] unexpected error fetching #{tracking_number}: #{e.class}: #{e.message}")
      Response.failed(error: "Carrier error: #{e.message}")
    end
  end
end
