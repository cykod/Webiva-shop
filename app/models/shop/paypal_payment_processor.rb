class Shop::PaypalPaymentProcessor < Shop::ActiveMerchantCreditCardProcessor

  def self.shop_payment_processor_handler_info
    info = super
    info[:name] = "Paypal Web Payments Pro Payment Processor"
    
    info
  end


  def self.get_options(hsh)
     Shop::PaypalPaymentProcessor::ProcessorOptions.new(hsh)
  end
  
  class ProcessorOptions < HashModel
   attributes :login => nil, :password => nil, :test_server => 'test', :signature => nil
   validates_presence_of :login, :password,:signature
  end
    
  def get_gateway 
      ActiveMerchant::Billing::Base.gateway_mode = @options[:test_server] == 'test' ? :test : :live
      ActiveMerchant::Billing::PaypalGateway.new(
              :login => @options[:login],
              :password => @options[:password],
              :test => (@options[:test_server] == 'test'),
              :signature => @options[:signature])
          
  end
  
  def self.options_partial
    '/shop/config/paypal_options'
  end
  
  def self.validate_options(opts)
    opts.valid?
  end
  
  def test?
    @options[:test_server] != 'live'
  end
  
end
