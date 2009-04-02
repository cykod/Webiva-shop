

class Shop::PaymentProcessor

  def initialize(processor,options,user)
    @processor = processor
    @opts = options || {}
    @user = user
  end
  
  def self.sanitize(payment_info)
    {}
  end
  
  def self.payment_record(transaction,payment_info)
    
    [ 'standard', nil,nil ]
  end
  
  def get_transaction_options(transaction,options = {})
    HashModel.new({})
  end
  
  
  def validate_payment_options(opts,user_info)
     nil
  end
  
  def payment_record(transaction,payment_info,options = {})
    [ 'standard', nil , '' ]
  end  
  
  

end
