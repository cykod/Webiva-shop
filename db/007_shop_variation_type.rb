class ShopVariationType < ActiveRecord::Migration
  def self.up
    add_column :shop_variations, :variation_type, :string, :default => 'option'
    add_column :shop_variation_options, :max, :integer
    add_column :shop_product_options, :max, :integer
    add_column :shop_product_features, :shop_product_class_id, :integer
    add_column :shop_product_features, :update_cart_callback, :boolean,:default => 0
    add_column :shop_products, :update_cart_callbacks, :integer, :default => 0
    add_column :shop_cart_products,:quantity_options, :text
  end

  def self.down
    remove_column :shop_variations, :variation_type
    remove_column :shop_variation_options, :max
    remove_column :shop_product_options, :max
    remove_column :shop_product_features, :shop_product_class_id
    remove_column :shop_products_features, :update_cart_callbacks
    remove_column :shop_products, :update_cart_callbacks
    remove_column :shop_cart_products,:quantity_options
  end

end
