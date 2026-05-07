require "test_helper"

class Carriers::FakeCarrierTest < ActiveSupport::TestCase
  setup do
    # Disable random failures and latency for deterministic assertions.
    Rails.application.config.carriers = {
      default: :fake,
      min_latency_ms: 0,
      max_latency_ms: 0,
      timeout_rate: 0.0,
      malformed_rate: 0.0
    }
  end

  test "returns a successful response with at least one event" do
    response = Carriers::FakeCarrier.new.fetch_tracking("1Z123ABC")

    assert response.success?, "expected success, got error: #{response.error.inspect}"
    assert response.events.any?
    assert response.events.first.is_a?(Carriers::Event)
    assert response.events.first.external_id.present?
  end

  test "response is deterministic per tracking number (idempotent)" do
    a = Carriers::FakeCarrier.new.fetch_tracking("1Z-DETERMINISTIC")
    b = Carriers::FakeCarrier.new.fetch_tracking("1Z-DETERMINISTIC")

    assert_equal a.events.map(&:external_id), b.events.map(&:external_id)
  end

  test "timeout from carrier becomes a failed response, not an exception" do
    Rails.application.config.carriers = Rails.application.config.carriers.merge(timeout_rate: 1.0)

    response = Carriers::FakeCarrier.new.fetch_tracking("1Z-DOOMED")

    assert response.failed?
    assert_match(/timed out/i, response.error)
  end

  test "malformed payload from carrier becomes a failed response" do
    Rails.application.config.carriers = Rails.application.config.carriers.merge(
      timeout_rate: 0.0,
      malformed_rate: 1.0
    )

    response = Carriers::FakeCarrier.new.fetch_tracking("1Z-BROKEN")

    assert response.failed?
    assert_match(/malformed/i, response.error)
  end
end
