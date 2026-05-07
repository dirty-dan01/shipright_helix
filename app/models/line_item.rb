class LineItem < ApplicationRecord
  belongs_to :order
  belongs_to :product

  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :unit_price_cents, numericality: { greater_than_or_equal_to: 0 }

  before_validation :snapshot_price_from_product, on: :create

  def unit_price
    Money.new(unit_price_cents, currency)
  end

  def subtotal
    Money.new(unit_price_cents * quantity, currency)
  end

  private

  def snapshot_price_from_product
    return unless product

    self.unit_price_cents ||= product.unit_price_cents
    self.currency ||= product.currency
  end
end
