class CategoryUrls < ActiveRecord::Migration
  def self.up
    add_column :shop_categories, :url, :string
    add_column :shop_categories, :weight, :integer, :default => 0
    add_column :shop_products, :taxable, :boolean, :default => true
    add_column :shop_products, :url, :string
    add_column :shop_payment_processors, :active, :boolean, :default => true 
  end

  def self.down
    remove_column :shop_categories, :url
    remove_column :shop_categories, :weight
    remove_column :shop_products, :taxable
    remove_column:shop_products, :url
    remove_column :shop_payment_processors, :active
  end
end
