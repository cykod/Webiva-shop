class ShopFields < ActiveRecord::Migration
  def self.up
    add_column :shop_products, :brand, :string
    add_column :shop_products, :name_2, :string

    execute "ALTER TABLE `shop_products`  ENGINE = MYISAM"
    execute "ALTER TABLE `shop_products` ADD FULLTEXT `text_search` (`name` ,`description` ,`internal_sku` ,`detailed_description`) "

  end

  def self.down
    remove_column :shop_products, :brand
    remove_column :shop_products, :name_2
  end


end
