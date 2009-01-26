
class Shop::BillLaterPaymentProcessor < Shop::PaymentProcessor
  
  def initialize(processor,options,user)
    @processor = processor
    @options = options || {}
    @user = user
  end
  
    
  def self.shop_payment_processor_handler_info
    { :name => 'Send Bill Later Payment',
#      :currencies => ['USD','CH],
      :type => 'Send Bill Later'
    }
  end   
  
  def self.get_options(hsh)
    Shop::BillLaterPaymentProcessor::ProcessorOptions.new(hsh)
  end
  
  class ProcessorOptions < HashModel
  
  end

  def self.validate_options(opts)
    opts.valid?
  end


  def self.get_transaction_options(transaction)
     Shop::BillLaterPaymentProcessor::PaymentOptions.new(transaction)
  end
  
  def self.validate_payment_options(opts,user_info)
  
  end
  
  class PaymentOptions < HashModel
  
  end  

  def self.options_partial
    nil
  end
  
  def self.transaction_partial
    "/shop/config/bill_later_form"
  end

  
  def format_authorization(auth)
    auth
  end
  
  def capture(authorization,currency,amount)
   Shop::ShopOrderTransaction::TransactionResponse.new(true,nil,'Bill Later Capture',{},false)
  end
  
  def credit(authorization,currency,amount)
    Shop::ShopOrderTransaction::TransactionResponse.new(true,nil,'Bill Later Credit',{},false)
  end
  
  
  def void(authorization)
   Shop::ShopOrderTransaction::TransactionResponse.new(true,nil,'Bill Later Void',{},false)
  end
  
  def authorize(parameters,currency,amount,user_info,request_options = {})
   Shop::ShopOrderTransaction::TransactionResponse.new(true,nil,'Bill Later Authorize',{},false)
  end
  
  def self.sanitize(payment)
    payment
  end
  
  def test?; false; end
  
  protected
  
  
end
