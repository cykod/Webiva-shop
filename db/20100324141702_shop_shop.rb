class ShopShop < ActiveRecord::Migration
  def self.up
    create_table :shop_shops, :force => true do |t|
      t.string :name
      t.string :abr
    end
    add_column :shop_products, :shop_shop_id, :string
    add_column :shop_product_classes, :content_model_id, :integer
    add_column :shop_product_features, :shop_shop_id, :integer
    begin
      remove_column :shop_product_prices, :sale_id 
      drop_table :shop_sales
    rescue 
      # slurp
    end
    add_column :shop_regions, :tax_calc, :string, :default => 'subtotal'
    add_column :shop_regions, :tax_processor, :string

    add_column :shop_subregions, :tax_calc, :string, :default => 'inherit'
  end

  def self.down
    
    drop_table :shop_shops
    remove_column :shop_products, :shop_shop_id
    remove_column :shop_product_classes, :content_model_id
    remove_column :shop_product_features, :shop_shop_id

    remove_column :shop_regions, :tax_calc
    remove_column :shop_regions, :tax_processor
    remove_column :shop_subregions, :tax_calc
  end
end
