require  File.expand_path(File.dirname(__FILE__)) + "/../../../../../../spec/spec_helper"


shared_examples_for "User Shopping Cart" do

  reset_domain_tables :shop_product, :shop_order, :shop_order_items, :shop_payment_processors, :end_user,:end_user_address, :shop_cart_products

  before(:each) do
    @shirt_cost = 14.95
    @shirt = Shop::ShopProduct.create(:name => 'A Shirt', :price_values => {'USD' => @shirt_cost})
    
    @coat_cost = 18.88
    @coat =  Shop::ShopProduct.create(:name => 'A Coat', :price_values => { 'USD' => @coat_cost})
  end


  it "should be able to add products to the cart" do
    @cart.add_product(@shirt,2)
    @cart.add_product(@coat,1)
    
    @cart.total.should == (@shirt_cost * 2 + @coat_cost)
  end
  
  it "should be able to modify the quantity of products in the cart" do
    @cart.add_product(@shirt,2)
    @cart.add_product(@coat,1)
    
    @cart.edit_product(@shirt,5)
    @cart.edit_product(@coat,0)
    
    @cart.total.should == (@shirt_cost * 5)    
  end
  
  it "should be able to return a total for only a couple of products" do
    @cart.add_product(@shirt,5)
    @cart.add_product(@coat,1)
    
    @cart.product_total([@shirt.id]).should == (@shirt_cost * 5 )    
  end 

end
