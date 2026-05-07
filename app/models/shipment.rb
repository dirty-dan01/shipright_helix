class Shipment < ApplicationRecord
  belongs_to :order
  has_many :tracking_events, dependent: :destroy

  validates :tracking_number, presence: true
  validates :carrier, presence: true

  STATUSES = %w[pending in_transit out_for_delivery delivered exception].freeze
  validates :status, inclusion: { in: STATUSES }

  def self.generate_tracking_number
    "1Z#{SecureRandom.alphanumeric(14).upcase}"
  end

  def latest_event
    tracking_events.order(occurred_at: :desc).first
  end

  def synced?
    last_synced_at.present?
  end
end
