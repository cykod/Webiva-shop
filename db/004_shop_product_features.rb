class ShopProductFeatures < ActiveRecord::Migration
  def self.up

    create_table :shop_product_features do |t|
      t.integer :shop_product_id
      t.string  :shop_feature_handler
      t.integer :position, :default => 0
      t.text :feature_options
      t.boolean :price_callback, :default => false
      t.boolean :purchase_callback, :default => false
      t.boolean :stock_callback, :default => false
      t.boolean :shipping_callback, :default => false
      t.boolean :rendering_callback, :default => false
      t.boolean :other_callback, :default => false
    end
    
    add_column :shop_products, :price_callbacks, :integer, :default => 0
    add_column :shop_products, :purchase_callbacks, :integer, :default => 0
    add_column :shop_products, :stock_callbacks, :integer, :default => 0
    add_column :shop_products, :shipping_callbacks, :integer, :default => 0
    add_column :shop_products, :rendering_callbacks, :integer, :default => 0
    add_column :shop_products, :other_callbacks, :integer, :default => 0
    
    add_index :shop_product_features, [:shop_product_id, :position ], :name => 'product'
  end

  def self.down
    drop_table :shop_product_features
    
    remove_column :shop_products, :price_callbacks
    remove_column :shop_products, :purchase_callbacks
    remove_column :shop_products, :stock_callbacks
    remove_column :shop_products, :shipping_callbacks
    remove_column :shop_products, :rendering_callbacks
    remove_column :shop_products, :other_callbacks
  end

end
