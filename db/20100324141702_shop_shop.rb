class ShopShop < ActiveRecord::Migration
  def self.up
    create_table :shop_shops, :force => true do |t|
      t.string :name
    end
    add_column :shop_products, :shop_shop_id, :string
    add_column :shop_product_classes, :content_model_id, :integer
  end

  def self.down
    drop_table :shop_shops
    remove_column :shop_products, :shop_shop_id
    remove_column :shop_product_classes, :content_model_id
  end
end
