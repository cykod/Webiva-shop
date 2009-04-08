require  File.expand_path(File.dirname(__FILE__)) + "/../../../../../../spec/spec_helper"


require 'shop/shop_order'


require  File.expand_path(File.dirname(__FILE__)) + '/shop_order_process_spec'

describe Shop::ShopOrder, "Test Payment Processor Order Process" do
  it_should_behave_like "General Order Process"

  # Go through the order process with a test payment processor
  before(:each) do
    create_test_payment_processor # from ShopOrderProcessHelper
  end
  
  it "should be able to output text and html order tables" do
    @cart.add_product(@shirt,2)
    @cart.add_product(@coat,1)
    
    @order = create_order(@cart)
   
    @transaction = @order.authorize_payment(:remote_ip => '127.0.0.1' )
    @transaction.should be_success
    @order.state.should == 'authorized'
    
    # Make sure the display_total is right
    @order.display_total.should == "$#{(@shirt_cost * 2 + @coat_cost)}"
    
    # Make sure the order html includes the shirt and coat name
    @order.format_order_html.should include(@shirt.name)
    @order.format_order_html.should include(@coat.name)
    @order.format_order_html.should include(@order.display_total)
    
    # Make sure the order text includes the shirt and coat name
    @order.format_order_text.should include(@shirt.name)
    @order.format_order_text.should include(@coat.name)
    @order.format_order_text.should include(@order.display_total)
  end
    
end
