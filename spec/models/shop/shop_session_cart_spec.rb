require  File.expand_path(File.dirname(__FILE__)) + "/../../../../../../spec/spec_helper"

require  File.expand_path(File.dirname(__FILE__)) + '/shop_cart_spec'

describe Shop::ShopSessionCart do
  it_should_behave_like "User Shopping Cart"
 
  before(:each) do
    @cart_session = []
    @cart = Shop::ShopSessionCart.new(@cart_session,'USD')
  end
  
    
end
