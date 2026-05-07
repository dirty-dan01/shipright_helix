ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    parallelize(workers: 1)

    def make_user(overrides = {})
      attrs = {
        name: "Test Staff #{SecureRandom.hex(2)}",
        email_address: "test-#{SecureRandom.hex(4)}@shipright.test",
        password: "password"
      }.merge(overrides)
      User.create!(attrs)
    end

    def make_customer(overrides = {})
      Customer.create!({
        name: "Customer #{SecureRandom.hex(2)}",
        email: "cust-#{SecureRandom.hex(4)}@example.test"
      }.merge(overrides))
    end

    def make_product(overrides = {})
      Product.create!({
        sku: "SKU-#{SecureRandom.hex(4).upcase}",
        name: "Test Product",
        unit_price_cents: 1000
      }.merge(overrides))
    end

    def make_order(customer: nil, products: nil, status: "pending")
      customer ||= make_customer
      products ||= [ make_product ]
      order = Order.new(customer: customer, status: status)
      products.each { |p| order.line_items.build(product: p, quantity: 1) }
      order.save!
      order
    end
  end
end
