require  File.expand_path(File.dirname(__FILE__)) + "/../../../../../../spec/spec_helper"

require  File.expand_path(File.dirname(__FILE__)) + '/shop_cart_spec'

describe Shop::ShopUserCart do
  it_should_behave_like "User Shopping Cart"
 
 
  before(:each) do
    @user = EndUser.push_target('tester@cykod.com')
    @cart = Shop::ShopUserCart.new(@user,'USD')
  end
  
 
end
