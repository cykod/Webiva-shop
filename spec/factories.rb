


  Factory.define :shop_product, :class => Shop::ShopProduct do |p|
    p.sequence(:name) { |n| "Shop Product #{n}" }
    p.sequence(:sku) { |n| "SKU-#{n}" }
  end


