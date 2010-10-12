class Shop::PayflowProPaymentProcessor < Shop::ActiveMerchantCreditCardProcessor
  
  def self.shop_payment_processor_handler_info
    info = super
    info[:name] = "PayflowPro Payment Processor"
    
    info
  end

  def self.remember_transactions?; true; end


  def self.get_options(hsh)
     Shop::PayflowProPaymentProcessor::ProcessorOptions.new(hsh)
  end
  
  class ProcessorOptions < HashModel
   default_options :login => nil, :password => nil, :test_server => false, :partner => nil
   validates_presence_of :login, :password, :partner
  end
    
  def get_gateway 
    PayflowGateway.new(
            :login => @options[:login],
            :password => @options[:password],
            :partner => @options[:partner],
            :test => !(@options[:test_server] == 'live')
        )
  end
  
  def self.options_partial
    '/shop/config/payflow_pro_options'
  end
  
  def self.validate_options(opts)
    opts.valid?
  end
  
  def test?
    @options[:test_server] != 'live'
  end
  
end
