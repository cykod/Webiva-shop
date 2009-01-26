class ShopUnit < ActiveRecord::Migration
  def self.up
    add_column :shop_products, :unit_quantity, :string
  end

  def self.down
    remove_column :shop_products, :unit_quantity
  end

end
