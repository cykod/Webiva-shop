require  File.expand_path(File.dirname(__FILE__)) + "/../../../../../../spec/spec_helper"


require 'shop/shop_order'


require  File.expand_path(File.dirname(__FILE__)) + '/shop_order_process_spec'

describe Shop::ShopOrder, "Test Payment Processor Order Process" do
  it_should_behave_like "General Order Process"

  # Go through the order process with a test payment processor
  before(:each) do
    create_test_payment_processor # from ShopOrderProcessHelper
  end
    
end
