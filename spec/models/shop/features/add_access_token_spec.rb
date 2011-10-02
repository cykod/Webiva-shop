require  File.expand_path(File.dirname(__FILE__)) + "/../../../../../../../spec/spec_helper"
require 'shop/shop_order'
require  File.expand_path(File.dirname(__FILE__)) + '/../shop_order_process_spec'

describe Shop::Features::AddAccessToken do
  it_should_behave_like "General Order Process"

  reset_domain_tables :shop_product_feature, :access_token, :end_user_token

  # Go through the order process with a test payment processor
  before(:each) do
    create_test_payment_processor # from ShopOrderProcessHelper

    @token = AccessToken.create :token_name => 'Paid Membership', :editor => 0, :description => ''
    @membership = Shop::ShopProduct.create(:name => 'Basic 1yr Membership', :price_values => { 'USD' => 25.00 })
    @feature = @membership.shop_product_features.build :position => 0, :feature_options => {:access_token_id => @token.id, :period => 365}, :purchase_callback => 1
    @feature.shop_feature_handler = Shop::Features::AddAccessToken.to_s.underscore
    @feature.save
    @membership.update_attribute :purchase_callbacks, 1
  end
  
  it "should be able to add access token to the user" do
    @membership.shop_product_features.count.should == 1
    @feature.should_not be_nil
    @feature.purchase_callback.should be_true
    @feature.shop_product_id.should == @membership.id

    @cart.add_product(@membership, 1)
    
    @order = create_order(@cart)

    @transaction = @order.authorize_payment(:remote_ip => '127.0.0.1' )
    
    @transaction.should be_success
    @order.state.should == 'authorized'
    
    @order.total.should == 25.00

    @capture_transaction = @order.capture_payment
    @capture_transaction.should be_success
    @order.state.should == 'paid'

    assert_difference 'EndUserToken.count', 1 do
      session = {}
      @order.post_process(@user,session)
    end

    eut = EndUserToken.find_by_end_user_id_and_access_token_id @user.id, @token.id
    eut.should_not be_nil
  end
end
