
class Shop::ShopPaymentProcessor < DomainModel
  
  validates_presence_of :payment_type, :processor_handler, :name
  validates_uniqueness_of :name
  validates_uniqueness_of :payment_type, :scope => :currency
  
  attr_protected :processor_handler
  
  serialize :options
  
  def processor_handler_class
    self.processor_handler.classify.constantize
  end
  
  def validate_payment_options(opts,user_info)
    self.processor_handler_class.validate_payment_options(opts,user_info)
  end

  def get_instance(user)
    processor_handler_class.new(self,options,user)
  end
  
  def sanitize(payment)
    processor_handler_class.sanitize(payment)
  end
  
  def payment_record(transaction,payment,options={})
    get_instance(transaction.end_user).payment_record(transaction,payment,options)
  end

  def test?
    get_instance(nil).test?
  end
end
