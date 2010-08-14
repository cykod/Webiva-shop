require  File.expand_path(File.dirname(__FILE__)) + "/../../../../../../spec/spec_helper"

add_factory_girl_path(File.join(File.expand_path(File.dirname(__FILE__)),"..",".."))

require 'pp'

describe Shop::ManageController do 

  reset_domain_tables :end_users, :shop_orders, :shop_order_transactions, :shop_order_items, :shop_order_actions, :shop_payment_processors
# transaction_reset

  integrate_views

 let(:payment_processor) do
      prc = Shop::ShopPaymentProcessor.new(
            :name => 'Test Processor',
            :currency => 'USD',
            :payment_type => 'Credit Card',
            :options => { :force_failure => "no" },
            :active => true)
      prc.processor_handler = 'shop/test_payment_processor'
      prc.save
      prc
   end



  before(:each) do 
    mock_editor
    @payment_processor = payment_processor # used by shop_rder
    @orders = 5.times.map { Factory.create(:shop_order, :shop_payment_processor_id => @payment_processor.id) }
  end

  it "should display the index page" do
    get :index
    response.should render_template('index')
  end

  it "should display the orders table" do
    controller.should handle_active_table(:order_table) do |args|
      post 'order_table', args
    end
  end
    
  it "should display an individual order" do
  
     get :order, :path => [ @orders[0].id.to_s ]
     response.should render_template('order')
  end

  it "should be able to download orders" do
    get :download
  end

  it "should display the capture order popup" do
    get :capture_order, :order_id => @orders[0].id.to_s
    response.should render_template('_capture_order')
  end


  it "should be able to capture an order" do
    post :capture_order, :order_id => @orders[0].id.to_s, :capture => "Capture"
    @orders[0].reload.state.should == 'paid' 
    response.should render_template('_update_order')
  end

  it "should be able to capture and ship an order" do 
    post :capture_order, :order_id => @orders[0].id.to_s, :ship => 1, :capture => 'Capture'
    @orders[0].reload.state.should == 'shipped' 
    response.should render_template('_update_order')
  end

  it "should not capture a shipped order" do
    @orders[0].payment_captured!
    @orders[0].shipped!
    @orders[0].state.should == 'shipped'
    post :capture_order, :order_id => @orders[0].id.to_s, :capture => "Capture"
    @orders[0].reload.state.should == 'shipped' 
    response.should render_template('_update_order')
  end

  it "should be able to display the ship order page" do
    get :ship_order, :order_id => @orders[0].id.to_s
    response.should render_template('_ship_order')
  end

 it "shoulds ship an order" do
    @orders[0].payment_captured!
    @orders[0].state.should == 'paid'
    post :ship_order, :order_id => @orders[0].id.to_s, :ship => "Capture", :shipment => {}
    @orders[0].reload.state.should == 'shipped' 
    response.should render_template('_update_order')
  end

 it "should display the void order template" do
   get :void_order, :order_id => @orders[0].id.to_s 
   response.should render_template('_void_order')
 end

  it "should be able to void an order" do 
    post :void_order, :order_id => @orders[0].id.to_s, :void => '1'
    @orders[0].reload.state.should == 'voided' 
  end

  it "should not void a paid order" do
    @orders[0].payment_captured!
    @orders[0].reload.state.should == 'paid'
    post :void_order, :order_id => @orders[0].id.to_s, :void => '1'
    @orders[0].reload.state.should == 'paid'
    response.should render_template('_update_order')
  end

  it "should display the refund order template"  do
   get :refund_order, :order_id => @orders[0].id.to_s 
   response.should render_template('_refund_order')
  end

  it "should be able to partially refund an order" do 
    @orders[0].capture_payment
    original_total = @orders[0].total
    post :refund_order, :order_id => @orders[0].id.to_s, :amount =>(10).to_s, :refund => "Refund"
    @orders[0].reload.state.should == 'partially_refunded' 
    @orders[0].total.should == original_total - 10
    @orders[0].refund.should == 10
  end

  it "should be be able to fully refund to an order" do
    @orders[0].capture_payment
    original_total = @orders[0].total
    post :refund_order, :order_id => @orders[0].id.to_s, :full => '1', :refund => 'Refund'
    @orders[0].reload
    @orders[0].state.should == 'fully_refunded' 
    @orders[0].total.should == 0
    @orders[0].refund.should == original_total
  end

  it "should be be able to fully refund to an order if the sent amount is greater than the total" do
    @orders[0].capture_payment
    original_total = @orders[0].total
    post :refund_order, :order_id => @orders[0].id.to_s, :amount => (@orders[0].total + 20).to_s, :refund => 'Refund'
    @orders[0].reload
    @orders[0].reload.state.should == 'fully_refunded' 
    @orders[0].total.should == 0
    @orders[0].refund.should == original_total
  end

  it "should not refund a authorized order" do
    post :refund_order, :order_id => @orders[0].id.to_s, :amount => (10).to_s, :refund => 'Refund'
    @orders[0].reload.state.should == 'authorized' 
  end

  it "should be able to add a note" do
    assert_difference "Shop::ShopOrderAction.count", 1 do
      post :add_note, :order_id => @orders[0].id.to_s,:note => { :note => 'Yay!' }
    end
  end

  it "shouldn't add a note if no note is posted" do
    assert_difference "Shop::ShopOrderAction.count", 0 do
      post :add_note, :order_id => @orders[0].id.to_s,:note => { :note => '' }
    end
  end

end
