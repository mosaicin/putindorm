class CreateOrdersAndOrderItems < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :phone
      t.text :address, null: false
      t.decimal :total, precision: 10, scale: 2, default: 0.0, null: false

      t.timestamps
    end

    create_table :order_items do |t|
      t.references :order, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.integer :quantity, null: false, default: 1
      t.decimal :unit_price, precision: 10, scale: 2, default: 0.0, null: false

      t.timestamps
    end
  end
end
