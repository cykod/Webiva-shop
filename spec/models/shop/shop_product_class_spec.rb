require  File.expand_path(File.dirname(__FILE__)) + "/../../../../../../spec/spec_helper"

add_factory_girl_path(File.join(File.expand_path(File.dirname(__FILE__)),"..",".."))


describe Shop::ShopProductClass do

 reset_domain_tables :shop_products, :shop_product_features, :shop_product_classes, :shop_product_options,
                    :shop_product_prices, :shop_product_translations, :shop_categories, :shop_category_products

 it "should be able to create a product class" do
   cls = Shop::ShopProductClass.create(:name => 'Test')

   cls.should be_valid
 end

 describe "Variation Options" do 

   before(:each) do
     @cls = Shop::ShopProductClass.create(:name => 'Test Cls')

     @cls.update_variations([
                            { :name => 'Color',
                              :variation_type => 'options',
                              :options => [
                                { :name => 'Red',:weight => "0.0",:prices => { "USD" => "1.0" } },
                                { :name => 'Blue',:weight => "0.0",:prices => { "USD" => "4.0" } },
                                { :name => 'Green',:weight => "0.0",:prices => { "USD" => "0.0" } }
                              ]
     },
       { :name => 'Size',
         :variation_type => 'options',
         :options => [
           { :name => 'SM',:weight => "0.0",:prices => { "USD" => "1.0" } },
           { :name => 'M',:weight => "1.0",:prices => { "USD" => "0.0" } },
           { :name => 'L',:weight => "2.0",:prices => { "USD" => "-7.0" } }
     ]
     }
     ])


   end

   it "should be able to create a class with variations and options" do

     @cls.shop_variations.length.should == 2
     @cls.shop_variations[0].options.length.should == 3

     @cls.shop_variations[0].options[1].name.should == 'Blue'
     @cls.shop_variations[1].options[2].name.should == 'L'
   end

   it "should give the correct price info for a shop product variation" do


     @product = Factory.create(:shop_product)
     @product.shop_product_class_id = @cls.id
     @product.save

     # base product priuce 
     calculated_price = @product.unit_cost('USD') + 4.0 - 7.0

     @product.get_options_price([ [ @cls.shop_variations[0].options[1], 'option' ],
                                 [ @cls.shop_variations[1].options[2], 'option' ] ],
                                 'USD', EndUser.default_user ).should == calculated_price

   end

    it "should be able to add and remove features from class" do
      activate_module('shop')

      @cls.features = [{:shop_feature_handler => "shop/features/add_user_tag", :id => "", :feature_options => {:add_tags => "new"}}]
      assert_difference 'Shop::ShopProductFeature.count', 1 do
        @cls.save
      end

      @feature = Shop::ShopProductFeature.last
      @feature.shop_product_class_id.should == @cls.id
      @feature.options.add_tags.should == "new"

      @cls = Shop::ShopProductClass.find @cls.id
      @cls.features = [{:shop_feature_handler => "shop/features/add_user_tag", :id => @feature.id, :feature_options => {:add_tags => "old"}}]

      assert_difference 'Shop::ShopProductFeature.count', 0 do
        @cls.save
      end

      @feature = Shop::ShopProductFeature.find @feature.id
      @feature.options.add_tags.should == 'old'

      @cls = Shop::ShopProductClass.find @cls.id
      @cls.features = []

      assert_difference 'Shop::ShopProductFeature.count', -1 do
        @cls.save
      end

      @feature = Shop::ShopProductFeature.find_by_id @feature.id
      @feature.should be_nil
    end
 end

end



