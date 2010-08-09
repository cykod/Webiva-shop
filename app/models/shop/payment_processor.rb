

class Shop::PaymentProcessor

  def initialize(processor,options,user)
    @processor = processor
    @options = options || {}
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
  
  def self.remember_transactions?
    false
  end
  
  def offsite?
    false
  end

  def can_authorize_payment?
    true
  end

  def offsite_redirect_url(order, return_url, cancel_url)
    nil
  end
end
