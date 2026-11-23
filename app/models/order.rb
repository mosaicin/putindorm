class Order < ApplicationRecord
  has_many :order_items, dependent: :destroy
  has_many :products, through: :order_items

  validates :name, :email, :address, presence: true
  validates :total, numericality: { greater_than: 0 }
  validates :payment_status, inclusion: { in: %w[pending succeeded canceled] }
  validates :public_token, :payment_idempotence_key, presence: true, uniqueness: true

  before_validation :set_payment_identifiers, on: :create

  def to_param
    public_token
  end

  private

  def set_payment_identifiers
    self.public_token ||= SecureRandom.hex(24)
    self.payment_idempotence_key ||= SecureRandom.uuid
  end
end
