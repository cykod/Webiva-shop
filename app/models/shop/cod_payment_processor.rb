
class Shop::CodPaymentProcessor < Shop::PaymentProcessor
  
  def initialize(processor,options,user)
    @processor = processor
    @options = options || {}
    @user = user
  end
  
    
  def self.shop_payment_processor_handler_info
    { :name => 'Check On Delivery (COD) Payment',
#      :currencies => ['USD','CH],
      :type => 'Check on Delivery (COD)'
    }
  end   
  
  def self.get_options(hsh)
    Shop::CodPaymentProcessor::ProcessorOptions.new(hsh)
  end
  
  class ProcessorOptions < HashModel
  
  end

  def self.validate_options(opts)
    opts.valid?
  end


  def self.get_transaction_options(transaction)
     Shop::CodPaymentProcessor::PaymentOptions.new(transaction)
  end
  
  def self.validate_payment_options(opts,user_info)
  
  end
  
  
  class PaymentOptions < HashModel
  
  end  

  def self.options_partial
    nil
  end
  
  def self.transaction_partial
    "/shop/config/cod_form"
  end

  
  def format_authorization(auth)
    auth
  end
  
  def capture(authorization,currency,amount)
   Shop::ShopOrderTransaction::TransactionResponse.new(true,nil,'COD Capture',{},false)
  end
  
  def credit(authorization,currency,amount)
    Shop::ShopOrderTransaction::TransactionResponse.new(true,nil,'COD Credit',{},false)
  end
  
  
  def void(authorization)
   Shop::ShopOrderTransaction::TransactionResponse.new(true,nil,'COD Void',{},false)
  end
  
  def authorize(parameters,currency,amount,user_info,request_options = {})
   Shop::ShopOrderTransaction::TransactionResponse.new(true,nil,'COD Authorize',{},false)
  end
  
  def self.sanitize(payment)
    payment
  end
  
  def test?; false; end
  
  protected
  
  
end
