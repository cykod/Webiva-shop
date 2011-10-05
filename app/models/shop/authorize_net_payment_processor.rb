class Shop::AuthorizeNetPaymentProcessor < Shop::ActiveMerchantCreditCardProcessor


  
  def self.shop_payment_processor_handler_info
    info = super
    info[:name] = "Authorize.net Payment Processor"
    
    info
  end


  def self.get_options(hsh)
     Shop::AuthorizeNetPaymentProcessor::ProcessorOptions.new(hsh)
  end
  
  class ProcessorOptions < HashModel
   default_options :login => nil, :password => nil, :test_server => false
   validates_presence_of :login, :password
  end
    
  def get_gateway 
    ActiveMerchant::Billing::AuthorizeNetGateway.new(
            :login => @options[:login],
            :password => @options[:password],
            :test => !(@options[:test_server] == 'live')
        )
  end
  
  def self.options_partial
    '/shop/config/authorize_net_options'
  end
  
  def self.validate_options(opts)
    opts.valid?
  end
  
  def test?
    @options[:test_server] != 'live'
  end

  def self.remember_transactions?
    true
  end
  
end
