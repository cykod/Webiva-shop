class ShopCouponMigration < ActiveRecord::Migration
  def self.up
  
    create_table :shop_coupons, :force => true do |t|
      t.string :internal_name
      t.text :internal_description
      t.string :cart_name
      t.string :cart_description
      t.string :code
      t.string :tag
      t.boolean :active, :default => true
      t.boolean :first_order, :default => false
      t.boolean :one_time, :default => true
      t.boolean :automatic, :default => false
      t.boolean :exclusive, :default => true
      t.datetime :expires_at
      t.boolean :all_products, :default => true
      t.string :discount_type, :default => 'amount'
      t.decimal :discount_amount, :precision=> 14, :scale => 2
      t.decimal :discount_percentage, :precision=> 14, :scale => 2
      t.timestamps
    end
    
    add_index :shop_coupons, :active, :name => 'active_index'
    
    create_table :shop_coupon_products,:force => true do |t|
      t.integer :shop_coupon_id
      t.string  :shop_product_id
    end
    
    add_index :shop_coupon_products, :shop_coupon_id, :name => 'coupon'
    
    add_column :shop_order_items, :processed, :boolean, :default => false
    add_column :shop_order_items, :shipped, :boolean, :default => false
    add_column :shop_order_items, :shop_order_shipment_id, :integer
    add_column :shop_order_items, :end_user_id, :integer
    
    create_table :shop_order_shipments do |t|
      t.integer :shop_order_id
      t.integer :end_user_id
      t.integer :shop_carrier_id
      t.string  :tracking_number
      t.date    :deliver_on
      t.timestamps
    end
  end

  def self.down
    drop_table :shop_coupons
    drop_table :shop_coupon_products
    
    remove_column :shop_order_items, :processed
    remove_column :shop_order_items, :shipped
    remove_column :shop_order_items, :shop_order_shipment_id
    remove_column :shop_order_items, :end_user_id
    
    drop_table :shop_order_shipments
  end


end
