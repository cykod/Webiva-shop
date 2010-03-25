require  File.expand_path(File.dirname(__FILE__)) + "/../../../../../../spec/spec_helper"


describe Shop::ShopCategory do

 reset_domain_tables :shop_categories


 it "should automatically create a url for a category" do
  
    cat_1 = Shop::ShopCategory.create(:name => 'Test Category')
    cat_2 = Shop::ShopCategory.create(:name => 'Test Category')
    cat_3 = Shop::ShopCategory.create(:name => 'My Test',:parent => cat_2)
   
    cat_1.url.should == 'test-category'
    cat_2.url.should == 'test-category-2'
    cat_1.parent.id.should == Shop::ShopCategory.get_root_category.id
    cat_3.parent.id.should == cat_2.id
 end

end






