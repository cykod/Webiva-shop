class ShopOptionUpdates < ActiveRecord::Migration
  def self.up
    add_column :shop_product_options, :image_id, :integer    
    add_column :shop_product_options, :in_stock, :boolean, :default => true
    
    add_column :shop_products, :in_stock, :boolean, :default => true
  end

  def self.down
    remove_column :shop_product_options, :image_id
    remove_column :shop_product_options, :in_stock
    
    remove_column :shop_products, :in_stock
  end
end
