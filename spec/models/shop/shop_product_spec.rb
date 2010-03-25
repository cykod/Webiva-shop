require  File.expand_path(File.dirname(__FILE__)) + "/../../../../../../spec/spec_helper"


describe Shop::ShopProduct do

 reset_domain_tables :shop_products, :shop_product_features, :shop_product_classes, :shop_product_options,
                    :shop_product_prices, :shop_product_translations

 it "should be able to create a product with just a name" do
   Shop::ShopProduct.create(:description => 'tester')
   Shop::ShopProduct.count.should == 0
   prd =  Shop::ShopProduct.create(:name => 'Test Product')

   Shop::ShopProduct.count.should == 1
 end

 it "should automatically create a url for a product" do

  prd =  Shop::ShopProduct.create(:name => 'My Test Product',:sku => '434')
  prd.url.should == 'my-test-product'

  prd2 =  Shop::ShopProduct.create(:name => 'My Test Product',:sku => '115')
  prd2.url.should == 'my-test-product-115'

  prd3 =  Shop::ShopProduct.create(:name => 'my test product',:sku => '115')
  prd3.url.should == 'my-test-product-115-2'

  prd4 =  Shop::ShopProduct.create(:name => 'my test product',:sku => '436')
  prd4.url.should == 'my-test-product-436'
 end
 


end




