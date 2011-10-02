class Shop::FreePaymentProcessor < Shop::PaymentProcessor

  # Descendent classes should override the following methods:
  
  def initialize(processor,options,user)
    @processor = processor
    @options = options
    @user = user
  end
  
  def self.shop_payment_processor_handler_info
    { 
      :currencies => ['USD'],
      :type => 'Free'
    }
  end
  
  def self.get_options(hsh)
    HashModel.new
  end
  
  def self.validate_options(opts)
    true
  end

  def self.options_partial
    "/application/options_partial"
  end
  
  def get_gateway
    nil
  end

  def test?
    false
  end
  
  # Shared methods that should be inherited
  

  def self.transaction_partial
    "/application/options_partial"
  end

  def get_transaction_options(transaction,options = {})
    HashModel.new
    opts
  end
  
  
  def validate_payment_options(opts,user_info)
    nil
  end
  
  
  def format_authorization(auth)
    auth
  end
  
  def capture(authorization,currency,amount)
    dummy_transaction
  end
  
  def credit(authorization,currency,amount)
    dummy_transaction
  end
  
  
  def void(authorization)
    dummy_transaction
  end
  
  def authorize(parameters,currency,amount,user_info,request_options = {})
    dummy_transaction
  end
  
  def dummy_transaction
    Shop::ShopOrderTransaction::TransactionResponse.new(
                  true,1,nil,{},false
      )
  end

  
  def self.sanitize(payment_info)
    payment_info
  end
  
  def payment_record(transaction,payment_info,options = {})
    [ "standard",nil,transaction.reference]
  end
  
end
