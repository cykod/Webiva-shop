class ShopOrderInfo < ActiveRecord::Migration
  def self.up
    add_column :shop_orders, :payment_reference, :string
    add_column :shop_orders, :shop_shipping_category_id, :integer
    

  end

  def self.down
    remove_column :shop_orders,:payment_reference
    remove_column :shop_orders,:shop_shipping_category_id
  end


end
