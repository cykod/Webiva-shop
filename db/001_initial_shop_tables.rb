class InitialShopTables < ActiveRecord::Migration
  def self.up

    # Need to define default weight metric
    create_table :shop_products , :force => true do |t|
      t.column :name, :string
      t.column :description, :text
      t.column :image_file_id, :integer
      t.column :download_file_id, :integer
      t.column :weight, :decimal, :precision=> 14, :scale => 2
      t.column :dimensions, :string
      t.column :size_level, :integer
      t.column :sku, :string
      t.column :internal_sku, :string
      t.column :fields, :text
      t.column :data, :text
      t.column :detailed_description, :text
      t.column :created_at, :datetime
      t.column :updated_at, :datetime
      t.column :active, :boolean, :default => false
      t.column :deleted, :boolean, :default => false
      t.column :min_quantity, :integer
      t.column :max_quantity, :integer
      t.column :stock_quantity, :integer
      t.column :sale_id, :integer
      t.column :shop_handler, :string
      t.column :distributor, :string
      t.column :shop_product_class_id, :integer
    end
    
    create_table :shop_product_files, :force => true do |t|
      t.integer :shop_product_id
      t.string :description
      t.string :file_type
      t.integer :domain_file_id
      t.integer :position, :default => 0
    end
    
    add_index :shop_product_files, :shop_product_id, :name => 'product_id'

    create_table :shop_product_translations, :force => true do |t|
       t.column :shop_product_id, :integer
       t.column :language, :string
       t.column :name, :string
       t.column :description, :text
       t.column :dimensions, :string
       t.column :detailed_description, :text
    end

    add_index :shop_product_translations, :shop_product_id, :name => 'product_id'

    create_table :shop_product_prices , :force => true do |t|
      t.column :shop_product_id, :integer
      t.column :sale_id, :integer
      t.column :price, :decimal, :precision=> 14, :scale => 2
      t.column :currency, :string, :limit => 3
    end

    add_index :shop_product_prices, [ :shop_product_id, :currency ], :name => 'product'

    create_table :shop_sales , :force => true do |t|
      t.column :name, :string
      t.column :start_at, :datetime
      t.column :end_at, :datetime
    end
    

    create_table :shop_cart_products , :force => true do |t|
      t.integer :end_user_id
      t.string :cart_item_type
      t.integer :cart_item_id
      t.text :options
      t.integer :quantity, :default => 1
    end

    add_index :shop_cart_products, :end_user_id, :name => 'end_user'

    create_table :shop_categories , :force => true do |t|
      t.column :name, :string
      t.column :parent_id, :integer, :null => false, :default => 0
      t.column :left_index, :integer, :mull => false, :default => 0
      t.column :depth, :integer, :null => false, :default => 0
    end

    add_index :shop_categories, [ :left_index, :name ] , :name => 'left_index_index'
    add_index :shop_categories, [ :parent_id, :name] , :name => 'parent'
    
    create_table :shop_category_products , :force => true do |t|
      t.column :shop_product_id, :integer
      t.column :shop_category_id, :integer
      t.column :featured, :boolean, :default => false
    end

    add_index :shop_category_products, :shop_category_id, :name => 'category_idx'
    add_index :shop_category_products, :shop_product_id, :name => 'product_idx'

    create_table :shop_variations, :force => true do |t|
      t.column :shop_product_class_id, :integer
      t.column :name, :string
    end
    
    add_index :shop_variations, :shop_product_class_id, :name => 'class'

    create_table :shop_variation_options, :force => true do |t|
      t.column :shop_variation_id, :integer
      t.column :name, :string
      t.column :option_index, :integer, :default => 0
      t.column :translations, :text
      t.column :prices, :text
      t.column :weight, :decimal, :precision => 14, :scale => 2, :default => 0.0
    end

    add_index :shop_variation_options, :shop_variation_id, :name => 'variation_id'

    create_table :shop_product_options, :force => true do |t|
      t.column :shop_variation_option_id, :integer
      t.column :shop_product_id, :integer
      t.column :option_sku, :string
      t.column :prices, :text
      t.column :weight, :decimal, :precision => 14, :scale => 2, :default => 0.0
      t.column :override, :boolean, :default => false
    end
    
    add_index :shop_product_options, [ :shop_product_id, :shop_variation_option_id ], :name => 'product_option'


    create_table :shop_orders , :force => true do |t|
      t.column :end_user_id, :integer
      t.column :name, :string
      t.column :updated_at, :datetime
      t.column :ordered_at, :datetime
      t.column :shipped_at, :datetime
      t.column :state, :string
      t.column :currency, :string
      t.column :subtotal, :decimal, :precision => 14, :scale => 2
      t.column :tax, :decimal, :precision => 14, :scale => 2
      t.column :shipping, :decimal, :precision => 14, :scale => 2
      t.column :total, :decimal, :precision => 14, :scale => 2
      t.column :shipping_address, :text
      t.column :billing_address, :text
      t.column :shop_payment_processor_id, :integer
      t.column :payment_information, :text
    end

    add_index :shop_orders, :ordered_at, :name => 'ordered'
    add_index :shop_orders, :updated_at, :name => 'updated'
    add_index :shop_orders, [:end_user_id,:ordered_at], :name => 'end_user'
    
    create_table :shop_order_items , :force => true do |t|
      t.integer :shop_order_id
      t.string :item_sku
      t.string :item_name
      t.string :item_details
      t.string :order_item_type
      t.integer :order_item_id
      t.text   :options
      t.string :currency, :limit => 3
      t.column :unit_price, :decimal,  :precision => 14, :scale => 2
      t.column :quantity, :integer, :default => 1
      t.column :subtotal, :decimal,  :precision => 14, :scale => 2
    end

    add_index :shop_order_items, :shop_order_id, :name => 'order'

    create_table :shop_order_transactions , :force => true do |t|
      t.integer :shop_order_id
      t.integer :shop_payment_processor_id
      t.string :currency, :limit => 3
      t.decimal :amount, :precision =>  14, :scale => 2
      t.string :action
      t.boolean :success
      t.string :reference
      t.string :message
      t.text :params
      t.boolean :test
      t.string :notes
      t.integer :processing_user_id
      t.timestamps
    end

    add_index :shop_order_transactions, :shop_order_id, :name => 'order_id'


    create_table :shop_product_classes, :force => true do |t|
      t.column :name, :string
    end
    

    create_table :shop_carriers, :force => true do |t|
      t.column :name, :string
      t.column :carrier_processor, :string
    end

    create_table :shop_regions, :force => true do |t|
      t.column :name, :string
      t.column :has_subregions, :boolean, :default => false
      t.column :subregion_type, :string
      t.column :tax, :decimal, :precision =>  14, :scale => 2
    end

    create_table :shop_region_countries, :force => true do |t|
      t.column :shop_region_id, :integer
      t.column :country, :string
    end

    add_index :shop_region_countries, :country, :name => 'country_index'
    add_index :shop_region_countries, :shop_region_id, :name => 'region_index'

    create_table :shop_subregions, :force => true do |t|
      t.column :shop_region_id, :integer
      t.column :name, :string
      t.column :abr, :string
      t.column :tax, :decimal, :precision => 14, :scale => 2
    end

    add_index :shop_subregions, :shop_region_id, :name => 'region_index'

    create_table :shop_shipping_categories, :force => true do |t|
      t.column :name, :string
      t.column :shop_carrier_id, :integer
      t.column :shop_region_id, :integer
      t.column :shipping_calculator, :string
      t.column :shipping_type, :string
      t.column :options, :text
      t.column :active, :boolean, :default => false
    end

  end

  def self.down
  end

end
