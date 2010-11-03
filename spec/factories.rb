
Factory.define :shop_product_class, :class => Shop::ShopProductClass do |p|
  p.sequence(:name) { |n| "Product Class #{n}" }
end

Factory.define :shop_product, :class => Shop::ShopProduct do |p|
  p.sequence(:name) { |n| "Shop Product #{n}" }
  p.sequence(:sku) { |n| "SKU-#{n}" }
  p.sequence(:internal_sku) { |n| "ISKU-#{n}" }
  p.shop_shop_id { |prd| Shop::ShopShop.default_shop.id  }
  p.price_values { |prd| { "USD" => rand(1000).to_f / 100 } }
  p.after_create { |prd|
    prd.add_category(Shop::ShopCategory.get_root_category)
  }
end

Factory.define :shop_category, :class => Shop::ShopCategory do |c|
  c.sequence(:name) { |n| "Shop Category #{n}" }
  c.parent_id { |cat| Shop::ShopCategory.get_root_category.id }
  c.url { |cat| cat.create_url }
end

Factory.define :shop_region_country, :class => Shop::ShopRegionCountry do |c|
  c.country "United States"
end

Factory.define :shop_region, :class => Shop::ShopRegion do |c|
  c.name "United States"
  c.has_subregions  false
  c.tax 0
  c.countries { |countries| [countries.association(:shop_region_country)] }
end


Factory.define :shop_carrier, :class => Shop::ShopCarrier do |sc|
  sc.name "Standard Carrier"
  sc.carrier_processor "shop/standard_carrier_processor"
end

Factory.define :shop_shipping_category, :class => Shop::ShopShippingCategory do |sc|
  sc.name "Standard Shipping"
  sc.active true
  sc.options({ :classes_shipping_cost => "item",
             :items => [ "" ],
             :item_prices => [ rand(1000).to_f / 100  ],
             :items_shipping_cost => "item",
             :shipping_calculation => "items" })
  sc.carrier { |carrier| carrier.association(:shop_carrier) }
  sc.region { |region| region.association(:shop_region) }
end

Factory.define :shop_order_items, :class => Shop::ShopOrderItem do |it|
  it.item_sku "Item"
  it.item_name "Item Name" 
  it.item_details "Some details go here yo!"
  it.currency "USD"
  it.unit_price { rand(10)+1 }
  it.quantity { rand(4)+1 }
  it.subtotal { |item| item.unit_price * item.quantity }
end

Factory.define :shop_order, :class => Shop::ShopOrder do |o|
  o.end_user { |end_user| end_user.association(:end_user) }
  o.name { |order| order.end_user.full_name }
  o.currency "USD"
  o.subtotal { |order| 12.0 + rand(10000).to_f / 100.0 }
  o.tax { rand(20) }
  o.shipping { rand(15) }
  o.total { |order| order.subtotal + order.tax + order.shipping }

  o.shipping_address({:address => "123 Elm St",:city => "Boston", :state => "MA", :country => "United States", :zip => "02113" })
  o.billing_address({:address => "123 Elm St",:city => "Boston", :state => "MA", :country => "United States", :zip => "02113" })
  o.shop_payment_processor_id { |order| Shop::ShopPaymentProcessor.find(:first) }
  o.payment_type 'standard'
  o.payment_reference { |order| rand(100000) }
  o.shop_shipping_category_id { |order| Shop::ShopShippingCategory.find(:first) }
  o.ordered_at { |order| Time.now - rand(600).days }

  o.order_items { |order| [order.association(:shop_order_items) ] }
  o.after_create { |order|
    order.payment_authorized!
    order.transactions.create(:currency => order.currency,:amount => order.total, :action => 'authorization', :success => 1, :test => 1, :end_user_id => order.end_user_id, :shop_payment_processor_id => order.shop_payment_processor_id )
  }
end
