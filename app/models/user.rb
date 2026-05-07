class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  validates :email_address, presence: true, uniqueness: { case_sensitive: false }
  validates :name, presence: true

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  def display_name
    name.presence || email_address
  end
end
