require "test_helper"

class OrderStateMachineTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  setup do
    @user  = make_user
    @order = make_order
  end

  # ---- Legal transitions ----------------------------------------------------

  test "pending order can transition to approved" do
    @order.transition_to!(:approved, actor: @user)
    assert_equal "approved", @order.reload.status
  end

  test "approved order can transition to fulfilled" do
    @order.update!(status: "approved")
    @order.transition_to!(:fulfilled, actor: @user)
    assert_equal "fulfilled", @order.reload.status
  end

  test "fulfilled order can transition to shipped" do
    @order.update!(status: "fulfilled")
    @order.transition_to!(:shipped, actor: @user)
    assert_equal "shipped", @order.reload.status
  end

  test "shipped order can transition to delivered" do
    @order.update!(status: "shipped")
    @order.transition_to!(:delivered, actor: @user)
    assert_equal "delivered", @order.reload.status
  end

  test "pending order can be cancelled" do
    @order.transition_to!(:cancelled, actor: @user)
    assert_equal "cancelled", @order.reload.status
  end

  # ---- Illegal transitions --------------------------------------------------

  test "pending order cannot skip to shipped" do
    error = assert_raises(OrderStateMachine::InvalidTransition) do
      @order.transition_to!(:shipped, actor: @user)
    end
    assert_match(/approved and fulfilled/i, error.message)
  end

  test "shipped order cannot be cancelled" do
    @order.update!(status: "shipped")
    error = assert_raises(OrderStateMachine::InvalidTransition) do
      @order.transition_to!(:cancelled, actor: @user)
    end
    assert_match(/already shipped/i, error.message)
  end

  test "delivered order is terminal" do
    @order.update!(status: "delivered")
    OrderStateMachine::STATES.each do |state|
      next if state == :delivered

      assert_raises(OrderStateMachine::InvalidTransition) do
        @order.transition_to!(state, actor: @user)
      end
    end
  end

  test "cancelled order is terminal" do
    @order.update!(status: "cancelled")
    assert_raises(OrderStateMachine::InvalidTransition) do
      @order.transition_to!(:approved, actor: @user)
    end
  end

  # ---- Audit trail ----------------------------------------------------------

  test "successful transition records an audit event with from/to/actor" do
    assert_difference -> { AuditEvent.count }, +1 do
      @order.transition_to!(:approved, actor: @user)
    end

    event = @order.audit_events.recent.first
    assert_equal "status_changed", event.event
    assert_equal "pending",   event.from_state
    assert_equal "approved",  event.to_state
    assert_equal @user, event.actor
  end

  test "failed transition does not change status or write audit event" do
    starting_status = @order.status

    assert_no_difference -> { AuditEvent.count } do
      assert_raises(OrderStateMachine::InvalidTransition) do
        @order.transition_to!(:shipped, actor: @user)
      end
    end

    assert_equal starting_status, @order.reload.status
  end

  # ---- can_transition_to? / available_transitions --------------------------

  test "available_transitions reflects current state" do
    assert_equal %i[approved cancelled], @order.available_transitions

    @order.update!(status: "shipped")
    assert_equal [ :delivered ], @order.available_transitions

    @order.update!(status: "delivered")
    assert_equal [], @order.available_transitions
  end

  # ---- Hook execution -------------------------------------------------------

  test "transitioning to shipped enqueues TrackingSyncJob" do
    @order.update!(status: "fulfilled")
    assert_enqueued_with(job: TrackingSyncJob) do
      @order.transition_to!(:shipped, actor: @user)
    end
    assert @order.shipment.present?
  end
end
