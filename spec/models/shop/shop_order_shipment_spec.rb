require  File.expand_path(File.dirname(__FILE__)) + "/../../../../../../spec/spec_helper"


require  File.expand_path(File.dirname(__FILE__)) + '/shop_order_process_spec'


describe Shop::ShopOrderShipment do


   include ShopOrderProcessHelper # Get some help from the shop_order_process_spec functionality
   
   reset_domain_tables :shop_product, :shop_order, :shop_order_items, :shop_payment_processors, :end_user,:end_user_address, :shop_cart_products


  before(:each) do
    @shirt_cost = 14.95
    @shirt = Shop::ShopProduct.create(:name => 'A Shirt', :price_values => {'USD' => @shirt_cost})
    
    @coat_cost = 18.88
    @coat =  Shop::ShopProduct.create(:name => 'A Coat', :price_values => { 'USD' => @coat_cost})
    
    create_test_user
    create_test_payment_processor
    @cart = Shop::ShopUserCart.new(@user,'USD')
  end
  
  it "should be able to partially ship an order" do
    @cart.add_product(@shirt,2)
    @cart.add_product(@coat,1)
    
    @order = create_order(@cart)
   
    @transaction = @order.authorize_payment(:remote_ip => '127.0.0.1' )
    @transaction.should be_success
    @order.state.should == 'authorized'
    
    @order.total.should == (@shirt_cost * 2 + @coat_cost)
    
    @capture_transaction = @order.capture_payment
    @capture_transaction.should be_success
    @order.state.should == 'paid'
    
    ship_items = [ @order.order_items[0] ]
    
    @shipment = @order.ship_order(ship_items,:tracking_number => 'XXXXXX', :deliver_on => Time.now+6.days)
    @order.state.should == 'partially_shipped'
    
    @shipment2 = @order.ship_order(nil,:tracking_number => 'YYYYY', :deliver_on => Time.now+6.days)
    @order.state.should == 'shipped'
    
    @order.reload
    
    @order.order_items.each do |oi|
      oi.should be_shipped
    end
    
  end
  

end  

