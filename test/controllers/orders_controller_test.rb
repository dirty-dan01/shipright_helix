require "test_helper"

class OrdersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user  = make_user
    @order = make_order
  end

  test "unauthenticated request is redirected to sign in" do
    get orders_url
    assert_redirected_to new_session_url
  end

  test "authenticated user sees the orders index" do
    sign_in_as(@user)
    get orders_url
    assert_response :success
    assert_select "h2", text: "Orders"
  end

  test "filtering by status narrows results" do
    sign_in_as(@user)

    other = make_order
    other.update!(status: "approved")

    get orders_url, params: { status: "pending" }
    assert_response :success
    assert_match @order.reference, response.body
    assert_no_match other.reference, response.body
  end

  test "transition action moves the order forward" do
    sign_in_as(@user)
    post transition_order_url(@order), params: { state: "approved" }
    assert_redirected_to order_url(@order)
    assert_equal "approved", @order.reload.status
  end

  test "invalid transition shows the user a message instead of crashing" do
    sign_in_as(@user)
    post transition_order_url(@order), params: { state: "shipped" }
    assert_redirected_to order_url(@order)
    assert_equal "pending", @order.reload.status
    follow_redirect!
    assert_match(/approved and fulfilled/i, response.body)
  end

  test "bulk_update applies action across selected orders" do
    sign_in_as(@user)
    other = make_order
    post bulk_update_orders_url, params: { state: "approved", order_ids: [ @order.id, other.id ] }

    assert_redirected_to orders_url
    assert_equal "approved", @order.reload.status
    assert_equal "approved", other.reload.status
  end

  private

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }
  end
end
