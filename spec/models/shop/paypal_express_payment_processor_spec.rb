require  File.expand_path(File.dirname(__FILE__)) + "/../../../../../../spec/spec_helper"
require 'shop/shop_order'
require  File.expand_path(File.dirname(__FILE__)) + '/shop_order_process_spec'

describe Shop::PaypalExpressPaymentProcessor do

#  reset_domain_tables :end_user, :shop_order, :shop_payment_processor

  def processor
    return @gw_processor if @gw_processor
    @user = EndUser.new :first_name => 'FirstName', :last_name => 'LastName'
    @payment_processor = Shop::ShopPaymentProcessor.new
    @gw_processor = Shop::PaypalExpressPaymentProcessor.new @payment_processor, {:login => 'test@test.dev', :password => 'password', :signature => 'XXXX'}, @user
  end

  def fakeweb_paypal_express_setup_purchase()
    url = "https://api-3t.paypal.com/2.0/"
    body = body.to_json unless body.is_a?(String)
    FakeWeb.register_uri :post, url, :body => '<SetExpressCheckoutResponse><Ack>Success</Ack><Token>YYYYYYYYYYYYYYYYYYYY</Token></SetExpressCheckoutResponse>', :content_type => 'text/xml'
  end

  def fakeweb_paypal_express_refund()
    url = "https://api-3t.paypal.com/2.0/"
    body = body.to_json unless body.is_a?(String)
    FakeWeb.register_uri :post, url, :body => '<RefundTransactionResponse><Ack>Success</Ack></RefundTransactionResponse>', :content_type => 'text/xml'
  end

  def fakeweb_paypal_express_purchase()
    url = "https://api-3t.paypal.com/2.0/"
    body = body.to_json unless body.is_a?(String)
    FakeWeb.register_uri :post, url,
      [ {:body => '<GetExpressCheckoutDetailsResponse><Ack>Success</Ack></GetExpressCheckoutDetailsResponse>', :content_type => 'text/xml'},
        {:body => '<DoExpressCheckoutPaymentResponse><Ack>Success</Ack></DoExpressCheckoutPaymentResponse>', :content_type => 'text/xml'}
      ]
  end

  it "should return expected values" do
    processor.can_authorize_payment?.should be_false
    processor.offsite?.should be_true
    processor.get_gateway.is_a?(ActiveMerchant::Billing::PaypalExpressGateway).should be_true
  end

  it "should not support authorize, void and capture transactions" do
    lambda{ processor.void(nil) }.should raise_exception(Shop::ShopOrderTransaction::TransactionError)
    lambda{ processor.authorize({},'USD',10.00,@user.attributes,{:remote_ip => '127.0.0.1', :parameters => {}}) }.should raise_exception(Shop::ShopOrderTransaction::TransactionError)
    lambda{ processor.capture(nil,'USD',10.00) }.should raise_exception(Shop::ShopOrderTransaction::TransactionError)
  end

  describe "Paypal Express Setup, Purchase and Refund" do
    before(:each) do
      FakeWeb.allow_net_connect = false
      FakeWeb.clean_registry

      @order = Shop::ShopOrder.new :total => 10.00
      @order.id = 5
    end

    it "should be able to get the authorization url" do
      remote_ip = '127.0.0.1'
      return_url = 'http://test.dev/success'
      cancel_url = 'http://test.dev/cancel'
      fakeweb_paypal_express_setup_purchase
      processor.offsite_redirect_url(@order, remote_ip, return_url, cancel_url).should == 'https://www.paypal.com/cgibin/webscr?cmd=_express-checkout&token=YYYYYYYYYYYYYYYYYYYY'
    end

    it "should be able to complete a purchase" do
      fakeweb_paypal_express_purchase
      trans = processor.purchase({}, 'USD', @order.total, @user.attributes, :remote_ip => '127.0.0.1', :parameters => {:token => 'YYYYYYYYYYYYYYYYYYYY', 'PayerID' => '2222'})
      trans.success?.should be_true
    end

    it "should be able to refund" do
      fakeweb_paypal_express_refund
      trans = processor.credit(nil, 'USD', @order.total)
      trans.success?.should be_true
    end
  end

end
