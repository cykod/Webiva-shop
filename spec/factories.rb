


Factory.define :shop_product, :class => Shop::ShopProduct do |p|
  p.sequence(:name) { |n| "Shop Product #{n}" }
  p.sequence(:sku) { |n| "SKU-#{n}" }
  p.sequence(:internal_sku) { |n| "ISKU-#{n}" }
  p.shop_shop_id { |prd| Shop::ShopShop.default_shop.id if prd.shop_shop_id.blank? }
  p.after_create { |prd|
    prd.add_category(Shop::ShopCategory.get_root_category)

  }
end

Factory.define :shop_category, :class => Shop::ShopCategory do |c|
  c.sequence(:name) { |n| "Shop Category #{n}" }
  c.parent_id { |cat| Shop::ShopCategory.get_root_category.id }
end



