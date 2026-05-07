require "test_helper"

class TrackingSyncJobTest < ActiveJob::TestCase
  setup do
    Rails.application.config.carriers = {
      default: :fake,
      min_latency_ms: 0,
      max_latency_ms: 0,
      timeout_rate: 0.0,
      malformed_rate: 0.0
    }

    user = make_user
    @order = make_order
    @order.update!(status: "fulfilled")
    @order.transition_to!(:shipped, actor: user)
    @shipment = @order.reload.shipment
  end

  test "fetches events and writes them to the shipment" do
    before = @shipment.tracking_events.count
    TrackingSyncJob.perform_now(@shipment.id)
    after = @shipment.reload.tracking_events.count

    assert_operator after, :>, before
    assert @shipment.synced?
    assert_nil @shipment.last_sync_error
  end

  test "is idempotent — re-running does not create duplicate events" do
    TrackingSyncJob.perform_now(@shipment.id)
    initial = @shipment.tracking_events.count

    assert_no_difference -> { @shipment.tracking_events.count } do
      TrackingSyncJob.perform_now(@shipment.id)
    end
  end

  test "records the error on the shipment when the carrier fails" do
    Rails.application.config.carriers = Rails.application.config.carriers.merge(timeout_rate: 1.0)

    TrackingSyncJob.perform_now(@shipment.id)

    @shipment.reload
    assert @shipment.last_sync_error.present?
    assert_equal 0, @shipment.tracking_events.count
  end

  test "missing shipment is a no-op (does not raise)" do
    assert_nothing_raised { TrackingSyncJob.perform_now(0) }
  end
end
