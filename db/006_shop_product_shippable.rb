class ShopProductShippable < ActiveRecord::Migration
  def self.up
    add_column :shop_products, :shippable,  :boolean, :default => true
  end

  def self.down
    remove_column :shop_products, :shippable
  end

end
