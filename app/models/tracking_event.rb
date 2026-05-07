class TrackingEvent < ApplicationRecord
  belongs_to :shipment

  validates :external_id, presence: true,
    uniqueness: { scope: :shipment_id }
  validates :status, presence: true
  validates :occurred_at, presence: true

  scope :chronological, -> { order(occurred_at: :asc) }
end
