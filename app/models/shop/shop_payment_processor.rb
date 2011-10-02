
class Shop::ShopPaymentProcessor < DomainModel
  
  validates_presence_of :payment_type, :processor_handler, :name
  validates_uniqueness_of :name
  validates_uniqueness_of :payment_type, :scope => [ :currency, :active], :if => Proc.new { |pp| pp.active? }
  
  attr_protected :processor_handler
  
  serialize :options
  
  def processor_handler_class
    self.processor_handler.classify.constantize
  end
  
  def validate_payment_options(user,opts,user_info)
    self.get_instance(user).validate_payment_options(opts,user_info)
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
  
  def offsite?
    get_instance(nil).offsite?
  end

  def offsite_redirect_url(order, remote_ip, return_url, cancel_url)
    get_instance(order.end_user).offsite_redirect_url(order, remote_ip, return_url, cancel_url)
  end

  def test?
    get_instance(nil).test?
  end

  def can_authorize_payment?
    get_instance(nil).can_authorize_payment?
  end


  def self.free_payment_processor
    handler = self.find_by_payment_type("free")
    
    if(!handler)  
      handler = self.new(:payment_type => 'Free', 
                  :active => 1,
                  :name => 'Zero-cost transations')
      handler.processor_handler =  'shop/free_payment_processor'
      handler.save
    end
    handler
  end
end
