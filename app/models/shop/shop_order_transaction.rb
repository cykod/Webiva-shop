
class Shop::ShopOrderTransaction < DomainModel

  belongs_to :order,
             :class_name => 'Shop::ShopOrder',
             :foreign_key => 'shop_order_id'
             
  belongs_to :end_user
         
  has_options :action, [ ['Authorization', 'authorization'],
                         ['Capture','capture'],
                         ['Void','void'],
                         ['Refund','credit'],
                         ['Payment','payment']
                        ]
  serialize :params
  
  def self.authorize(user,processor,parameters,currency,amount,user_info = {},request_options = {}) 
    process(user,processor,'authorization',currency,amount) do
      processor.get_instance(user).authorize(parameters,currency,amount,user_info,request_options)
    end
  end
  
  def self.purchase(user,processor,parameters,currency,amount,user_info = {},request_options = {}) 
    process(user,processor,'payment',currency,amount) do
      processor.get_instance(user).purchase(parameters,currency,amount,user_info,request_options)
    end
  end
  
  def self.capture(user,processor,authorization,currency,amount)
    process(user,processor,'capture',currency,amount) do
      processor.get_instance(user).capture(authorization,currency,amount)
    end    
  end
  
  def self.refund(user,processor,authorization,currency,amount)
    process(user,processor,'credit',currency,amount) do
      processor.get_instance(user).credit(authorization,currency,amount)
    end
  end
  
  def self.void(user,processor,authorization)
    process(user,processor,'void') do
      processor.get_instance(user).void(authorization)
    end
  end
  
  private
  
  def self.process(user,processor,action,currency=nil,amount=nil)
  
    result = Shop::ShopOrderTransaction.new
    result.end_user= user
    result.shop_payment_processor_id = processor.id
    result.currency = currency
    result.amount = amount
    result.action = action
    
    begin
      response = yield 
      
      result.success = response.success?
      result.reference = response.reference
      result.message = response.message
      result.params = response.params
      result.test = response.test?
    rescue Shop::ShopOrderTransaction::TransactionError => e
      result.success = false
      result.reference = nil
      result.message = e.message
      result.params = {}
      result.test = processor.test?
    end
    
    result
  end
  
  public
  
  class TransactionError < Exception
    attr_reader :message
    
    def initialize(message)
      @message = message
    end
  end
  
  class TransactionResponse 
    attr_reader :reference,:message,:params
    
    def initialize(success,reference,message,params,test)
      @success = success
      @reference = reference
      @message = message
      @params = params
      @test = test
    end
    
    def success?
      @success
    end
    
    def test?
      @test
    end
  end
  
  def display_amount
    if amount && currency
      Shop::ShopProductPrice.localized_amount(amount,currency)    
    else
      '-'
    end
  end
  
end
