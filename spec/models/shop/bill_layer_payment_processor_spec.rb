require  File.expand_path(File.dirname(__FILE__)) + "/../../../../../../spec/spec_helper"

require  File.expand_path(File.dirname(__FILE__)) + '/shop_order_process_spec'

describe Shop::BillLaterPaymentProcessor do
  it_should_behave_like "General Order Process"

  # Go through the order process with a test payment processor
  before(:each) do
    @shop_processor = Shop::ShopPaymentProcessor.new(:name => 'Test Processor',:currency => 'USD',
                          :payment_type => 'Send Bill Later',:options => {  })
    @shop_processor.processor_handler = "shop/bill_later_payment_processor"
    @shop_processor.save
  end
    
end
