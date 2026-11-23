class Product < ApplicationRecord
  validates :name, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  before_validation :apply_defaults

  private

  def apply_defaults
    self.category = "General" if category.blank?
    self.description = "Описание товара появится позже." if description.blank?
    self.image_url = "https://images.unsplash.com/photo-1521572267360-ee0c2909d518?auto=format&fit=crop&w=800&q=80" if image_url.blank?
  end
end
