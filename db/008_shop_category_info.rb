class ShopCategoryInfo < ActiveRecord::Migration
  def self.up
    add_column :shop_categories, :description, :text
  end

  def self.down
    remove_column :shop_categories, :description
  end

end
