require  File.expand_path(File.dirname(__FILE__)) + "/../../../../../../spec/spec_helper"

describe Shop::ManageController do
 
 
  reset_domain_tables :content_types

 
  before(:each) do
   
  end

  it "should be able to create a content type for products" do

    lambda {
      Shop::AdminController.content_node_type_generate
    }.should change { ContentType.count  }.by(1)
    
    ct = ContentType.find(:last)
    
    ct.content_name.should == "Shop Product"
    ct.content_type.should == 'Shop::ShopProduct'
  end
  
end

