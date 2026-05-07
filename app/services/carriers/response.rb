module Carriers
  class Response
    attr_reader :events, :status, :error, :raw_payload

    def initialize(success:, events: [], status: nil, error: nil, raw_payload: nil)
      @success = success
      @events = events
      @status = status
      @error = error
      @raw_payload = raw_payload
    end

    def success?
      @success
    end

    def failed?
      !success?
    end

    def self.success(events:, status:, raw_payload: nil)
      new(success: true, events: events, status: status, raw_payload: raw_payload)
    end

    def self.failed(error:, raw_payload: nil)
      new(success: false, error: error, raw_payload: raw_payload)
    end
  end

end
