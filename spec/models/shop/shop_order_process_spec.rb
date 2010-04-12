require  File.expand_path(File.dirname(__FILE__)) + "/../../../../../../spec/spec_helper"

module ShopOrderProcessHelper


  def create_order(cart)
    order = Shop::ShopOrder.generate_order(@user)
    order.should be_valid
    
    payment_info = { :type => 'standard',
                      :card_type => 'visa',
                      :cc => '1',
                      :exp_month => '12',
                      :exp_year => '2100'
                    }
                        
    
    order.pending_payment( :currency => cart.currency,
                                :tax => 0.00,
                                :shipping => 0.00,
                                :shipping_address => @user.shipping_address.attributes,
                                :billing_address => @user.billing_address.attributes,
                                :shop_payment_processor => @shop_processor,
                                :shop_shipping_category_id => nil ,
                                :user => @user,
                                :cart => cart,
                                :payment => payment_info
                              )    
    order.state.should == 'pending'
    order
  end
  
  def create_test_payment_processor
    @shop_processor = Shop::ShopPaymentProcessor.new(:name => 'Test Processor',:currency => 'USD',
                          :payment_type => 'Create Card',:options => { :force_failure => 'no' })
    @shop_processor.processor_handler = "shop/test_payment_processor"
    @shop_processor.save
  end
  
  def create_test_user
    @user = EndUser.push_target('tester@cykod.com')
    @user.billing_address = EndUserAddress.create(:end_user_id => @user.id,:address => '123 Elm St.',:city => 'boston',:state => 'ma',:zip => '02134')
    @user.shipping_address = EndUserAddress.create(:end_user_id => @user.id,:address => '123 Elm St.',:city => 'boston',:state => 'ma',:zip => '02134')  
  end
end

shared_examples_for "General Order Process" do
 include ShopOrderProcessHelper
 
 reset_domain_tables :shop_product, :shop_order, :shop_order_items, :shop_payment_processors, :end_user,:end_user_address, :shop_cart_products
  
  before(:each) do
    @shirt_cost = 14.95
    @shirt = Shop::ShopProduct.create(:name => 'A Shirt', :price_values => { 'USD' => @shirt_cost })
    
    @coat_cost = 18.88
    @coat =  Shop::ShopProduct.create(:name => 'A Coat', :price_values => { 'USD' => @coat_cost })
    
    create_test_user
  
    @cart = Shop::ShopUserCart.new(@user,'USD')
  end
  
  it "should be able to purchase a product" do
    @cart.add_product(@shirt,2)
    @cart.add_product(@coat,1)
    
    @order = create_order(@cart)
   
    @transaction = @order.authorize_payment(:remote_ip => '127.0.0.1' )
    session = {}
    @order.post_process(@user,session)
    
    @transaction.should be_success
    @order.state.should == 'authorized'
    
    @order.total.should == (@shirt_cost * 2 + @coat_cost)
    
    @capture_transaction = @order.capture_payment
    @capture_transaction.should be_success
    @order.state.should == 'paid'
    
    @order.ship_order
    @order.state.should == 'shipped'
    
    @refund_transaction = @order.refund_order(15.00)
    @refund_transaction.should be_success
    @order.state.should == 'partially_refunded'
    
    @refund_transaction = @order.refund_order((@shirt_cost * 2 + @coat_cost) - 15.00)
    @refund_transaction.should be_success
    @order.state.should == 'fully_refunded'
    
  end

end
