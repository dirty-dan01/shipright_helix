require "test_helper"

class LineItemTest < ActiveSupport::TestCase
  test "snapshots the product price at creation" do
    product = make_product(unit_price_cents: 1500)
    order = make_order(products: [ product ])

    line_item = order.line_items.first
    assert_equal 1500, line_item.unit_price_cents

    product.update!(unit_price_cents: 9999)
    assert_equal 1500, line_item.reload.unit_price_cents
  end

  test "subtotal multiplies unit price by quantity" do
    product = make_product(unit_price_cents: 250)
    order = make_order(products: [ product ])
    line_item = order.line_items.first
    line_item.update!(quantity: 4)

    assert_equal 1000, line_item.subtotal.cents
  end
end
