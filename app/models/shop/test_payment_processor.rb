class Shop::TestPaymentProcessor < Shop::ActiveMerchantCreditCardProcessor
  
  def self.shop_payment_processor_handler_info
    info = super
    info[:name] = "Test Payment Processor"
    info
  end


  def self.get_options(hsh)
     ProcessorOptions.new(hsh)
  end
  
  class ProcessorOptions < HashModel
   default_options :force_failure => 'no'
   validates_presence_of :force_failure
  end
  
  
  def self.options_partial
    '/shop/config/test_payment_processor_options'
  end  
  
  def get_gateway 
    BogusGateway.new
  end
  
  def format_authorization(auth)
    if @options[:force_failure] == 'yes'
      '2'
    elsif @options[:force_failure] == 'exception'
      '1'
    else
      auth
    end
  end
  
  def self.validate_options(opts)
    opts.valid?
  end


  def test?
    true
  end
end
