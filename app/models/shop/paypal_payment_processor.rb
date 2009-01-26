
class Shop::PaypalPaymentProcessor 
  include ActiveMerchant::Billing
  
  def initialize(options)
    @options = options || {}
  end
  
    
  def self.shop_payment_processor_handler_info
    { :name => 'Paypal External Payments',
      :currencies => ['USD'],
      :type => 'Paypal External'
    }
  end   
  
  def self.get_options(hsh)
    Shop::PaypalPaymentProcessor::ProcessorOptions.new(hsh)
  end
  
  class ProcessorOptions < HashModel
  
  end

  def self.validate_options(opts)
    opts.valid?
  end


  def get_transaction_options(transaction)
    Shop::PaypalPaymentProcessor::PaymentOptions.new(hsh)
  end
  
  class PaymentOptions < HashModel
  
  end  

end
