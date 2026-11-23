require "securerandom"

class AddYookassaPaymentFieldsToOrders < ActiveRecord::Migration[8.1]
  def up
    add_column :orders, :payment_status, :string, default: "pending", null: false
    add_column :orders, :payment_id, :string
    add_column :orders, :payment_url, :string
    add_column :orders, :payment_idempotence_key, :string
    add_column :orders, :public_token, :string

    connection.select_values("SELECT id FROM orders").each do |id|
      connection.execute(
        "UPDATE orders SET payment_idempotence_key = #{connection.quote(SecureRandom.uuid)}, " \
        "public_token = #{connection.quote(SecureRandom.hex(24))} WHERE id = #{connection.quote(id)}"
      )
    end

    change_column_null :orders, :payment_idempotence_key, false
    change_column_null :orders, :public_token, false
    add_index :orders, :payment_id, unique: true
    add_index :orders, :payment_idempotence_key, unique: true
    add_index :orders, :public_token, unique: true
  end

  def down
    remove_index :orders, :public_token
    remove_index :orders, :payment_idempotence_key
    remove_index :orders, :payment_id
    remove_column :orders, :public_token
    remove_column :orders, :payment_idempotence_key
    remove_column :orders, :payment_url
    remove_column :orders, :payment_id
    remove_column :orders, :payment_status
  end
end
