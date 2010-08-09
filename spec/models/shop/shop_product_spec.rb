require  File.expand_path(File.dirname(__FILE__)) + "/../../../../../../spec/spec_helper"


describe Shop::ShopProduct do

 reset_domain_tables :shop_products, :shop_product_features, :shop_product_classes, :shop_product_options,
                    :shop_product_prices, :shop_product_translations

 it "should be able to create a product with just a name and a price" do
   Shop::ShopProduct.create(:description => 'tester')
   assert_difference "Shop::ShopProduct.count", 1 do
     prd =  Shop::ShopProduct.create(:name => 'Test Product', :price_values => { "USD" => 12.75 } )

     prd.unit_cost('USD').should == 12.75
   end
 end

 it "should automatically create a url for a product" do

  prd =  Shop::ShopProduct.create(:name => 'My Test Product',:sku => '434', :price_values => { "USD" => "0.00" }  )
  prd.url.should == 'my-test-product'

  prd2 =  Shop::ShopProduct.create(:name => 'My Test Product',:sku => '115', :price_values => { "USD" => "0.00" } )
  prd2.url.should == 'my-test-product-115'

  prd3 =  Shop::ShopProduct.create(:name => 'my test product',:sku => '115', :price_values => { "USD" => "0.00" } )
  prd3.url.should == 'my-test-product-115-2'

  prd4 =  Shop::ShopProduct.create(:name => 'my test product',:sku => '436', :price_values => { "USD" => "0.00" } )
  prd4.url.should == 'my-test-product-436'
 end

  it "should be able to copy another product" do
    prd =  Shop::ShopProduct.create(:name => 'My Test Product',:sku => '434', :price_values => { "USD" => "0.00" }  )
    new_prd = nil
    assert_difference 'Shop::ShopProduct.count', 1 do
      new_prd = prd.copy_product
    end
    new_prd.url.should == 'my-test-product-copy'
  end
end




