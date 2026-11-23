class AddCatalogFieldsToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :price, :decimal, precision: 10, scale: 2, default: 0.0, null: false
    add_column :products, :description, :text
    add_column :products, :image_url, :string
    add_column :products, :category, :string, default: "General", null: false
    add_column :products, :featured, :boolean, default: false, null: false
  end
end
