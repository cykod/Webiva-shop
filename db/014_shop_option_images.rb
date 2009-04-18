class ShopOptionImages < ActiveRecord::Migration
  def self.up
    add_column :shop_product_options, :image_list, :text
  end

  def self.down
    remove_column :shop_product_options, :image_list, :text
  end
end
