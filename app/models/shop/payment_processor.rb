

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

end
