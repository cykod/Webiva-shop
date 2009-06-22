class ShopOrderGift < ActiveRecord::Migration
  def self.up
    add_column :shop_orders, :gift_order, :boolean, :default => false
    add_column :shop_orders, :gift_message, :text
  end

  def self.down
    remove_column :shop_orders, :gift_order
    remove_column :shop_orders, :gift_message
  end
end
