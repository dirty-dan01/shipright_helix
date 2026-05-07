require "test_helper"

class Orders::BulkTransitionTest < ActiveSupport::TestCase
  setup do
    @user = make_user
  end

  test "applies transition to every eligible order" do
    orders = Array.new(3) { make_order }

    result = Orders::BulkTransition.new(
      orders: Order.where(id: orders.map(&:id)),
      target_state: :approved,
      actor: @user
    ).call

    assert_equal 3, result.succeeded.size
    assert_empty result.failed
    assert orders.all? { |o| o.reload.status == "approved" }
  end

  test "collects per-order failures without aborting the batch" do
    valid     = make_order                                           # pending
    delivered = make_order                                           # cannot be approved
    delivered.update!(status: "delivered")
    cancelled = make_order
    cancelled.update!(status: "cancelled")

    result = Orders::BulkTransition.new(
      orders: Order.where(id: [ valid, delivered, cancelled ].map(&:id)),
      target_state: :approved,
      actor: @user
    ).call

    assert_equal 1, result.succeeded.size
    assert_equal 2, result.failed.size
    assert result.partial?
    assert_equal "approved", valid.reload.status
    assert_equal "delivered", delivered.reload.status
  end

  test "result summary describes mixed outcomes" do
    valid = make_order
    blocked = make_order
    blocked.update!(status: "delivered")

    result = Orders::BulkTransition.new(
      orders: Order.where(id: [ valid, blocked ].map(&:id)),
      target_state: :approved,
      actor: @user
    ).call

    assert_match(/1 order updated/, result.summary)
    assert_match(/1 skipped/, result.summary)
    assert result.failure_details.first.include?(blocked.reference)
  end

  test "every order transition is audited even in bulk" do
    orders = Array.new(2) { make_order }

    assert_difference -> { AuditEvent.count }, +2 do
      Orders::BulkTransition.new(
        orders: Order.where(id: orders.map(&:id)),
        target_state: :approved,
        actor: @user
      ).call
    end
  end
end
