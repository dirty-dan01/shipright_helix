class Order < ApplicationRecord
  include Auditable
  include OrderStateMachine

  belongs_to :customer
  has_many :line_items, dependent: :destroy
  has_one :shipment, dependent: :destroy

  accepts_nested_attributes_for :line_items, allow_destroy: true

  validates :reference, presence: true, uniqueness: true
  validates :customer, presence: true

  before_validation :assign_reference, on: :create

  after_transition_to :shipped do
    shipment_record = shipment || build_shipment(
      tracking_number: Shipment.generate_tracking_number,
      status: "pending"
    )
    shipment_record.save! if shipment_record.new_record?

    TrackingSyncJob.perform_later(shipment_record.id)
  end

  after_transition_to :approved do
    broadcast_dashboard_update
  end
  after_transition_to :fulfilled do
    broadcast_dashboard_update
  end
  after_transition_to :shipped do
    broadcast_dashboard_update
  end
  after_transition_to :delivered do
    broadcast_dashboard_update
  end
  after_transition_to :cancelled do
    broadcast_dashboard_update
  end

  def total
    line_items.reduce(Money.zero(currency)) { |sum, li| sum + li.subtotal }
  end

  def currency
    line_items.first&.currency || "USD"
  end

  private

  def assign_reference
    return if reference.present?

    self.reference = "SR-#{Time.current.strftime('%Y%m')}-#{SecureRandom.alphanumeric(4).upcase}"
  end

  def broadcast_dashboard_update
    broadcast_replace_to "orders:index",
      target: ActionView::RecordIdentifier.dom_id(self, :row),
      partial: "orders/row",
      locals: { order: self }
  rescue StandardError => e
    Rails.logger.warn("[Order#broadcast_dashboard_update] #{e.class}: #{e.message}")
  end
end
