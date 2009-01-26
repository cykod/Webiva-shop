class ShopOrderFeatures < ActiveRecord::Migration
  def self.up

    add_column :shop_orders, :refund, :decimal, :precision=> 14, :scale => 2, :default => 0.0
    
    create_table :shop_order_actions do |t|
      t.integer :shop_order_id
      t.integer :shop_order_transaction_id
      t.boolean :success
      t.integer :end_user_id
      t.string :order_action
      t.datetime :created_at
      t.text :note
    end

  end

  def self.down
    remove_column :shop_orders, :refund

    drop_table :shop_order_actions
  end

end
