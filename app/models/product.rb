class Product < ApplicationRecord
  has_many :line_items, dependent: :restrict_with_error

  validates :sku, presence: true, uniqueness: true
  validates :name, presence: true
  validates :unit_price_cents, numericality: { greater_than_or_equal_to: 0 }

  def unit_price
    Money.new(unit_price_cents, currency)
  end
end
