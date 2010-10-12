class Shop::ActiveMerchantCreditCardProcessor < Shop::PaymentProcessor
  include ActiveMerchant::Billing

  # Descendent classes should override the following methods:
  
  def initialize(processor,options,user)
    @processor = processor
    @options = options
    @user = user
  end
  
  def self.shop_payment_processor_handler_info
    { 
      :currencies => ['USD'],
      :type => 'Credit Card'
    }
  end
  
  def self.get_options(hsh)
    raise "Override get_options"
  end
  
  def self.validate_options(opts)
    opts.valid?
  end

  def self.options_partial
    raise "Override options_partial"
  end
  
  def get_gateway
    raise 'Override get gateway'
  end
  
  # Shared methods that should be inherited
  

  def self.transaction_partial
    "/shop/config/credit_card_form"
  end

  def get_transaction_options(transaction,options = {})
    opts = Shop::ActiveMerchantCreditCardProcessor::PaymentOptions.new(transaction)

    order = Shop::ShopOrder.remember_transaction(@processor,@user, :admin => options[:admin])
    
    opts.reference_card = order.payment_identifier if order

    opts
  end
  
  class PaymentOptions < HashModel
    default_options :cc => nil, :card_type => nil, :exp_month => nil, :exp_year => nil, :cvc => nil, :type => 'reference',:remember => 0, :reference_card => nil
    
    has_options :card_type, [[ 'Visa', 'visa'],['MasterCard','master'],['American Express','american_express' ]]
    integer_options :remember
    validates_presence_of :cc, :card_type, :exp_month, :exp_year, :cvc, :if => Proc.new { |elm| elm.type != 'reference' }
  end
  
  def validate_payment_options(opts,user_info)
    opts = get_transaction_options(opts)
    return opts.errors unless opts.valid?

    if opts.type == 'reference'
      #    
    else
      credit_card = ActiveMerchant::Billing::CreditCard.new({ 
        :type => opts.card_type,
        :number => opts.cc,
        :verification_value => opts.cvc,
        :month => opts.exp_month,
        :year => opts.exp_year,
        :first_name => user_info[:first_name],
        :last_name => user_info[:last_name]
      });

      return credit_card.errors unless credit_card.valid?
    end
    
    nil
  end
  
  
  def format_authorization(auth)
    auth
  end
  
  def capture(authorization,currency,amount)
    return standard_transaction(currency) do |gw|
      response = gw.capture(amount * 100,format_authorization(authorization))
    end
  end
  
  def credit(authorization,currency,amount)
    return standard_transaction(currency) do |gw|
      response = gw.credit(amount * 100,format_authorization(authorization))
    end
  end
  
  
  def void(authorization)
    return standard_transaction do |gw|
      if gw.class.method_defined?('void')
        response = gw.void(format_authorization(authorization))
      else
        raise Shop::ShopOrderTransaction::TransactionError.new('Void not supported')
      end
    end
  end
  
  def authorize(parameters,currency,amount,user_info,request_options = {})
    gw = get_gateway
    
    if currency != 'USD'
      return Shop::ShopOrderTransaction::TransactionResponse.new(false,nil,'Invalid Currency',{},gw.test?)
    end 
    
    reference = nil
    if parameters[:type] == 'reference'
      order = Shop::ShopOrder.remember_transaction(@processor,@user, :admin => request_options[:admin],:transaction => true)
      reference = order.payment_reference if order
    else
      credit_card = ActiveMerchant::Billing::CreditCard.new({ 
        :type => parameters[:card_type],
        :number => parameters[:cc],
        :month => parameters[:exp_month],
        :verification_value => parameters[:cvc],
        :year => parameters[:exp_year],
        :first_name => user_info[:user][:first_name],
        :last_name => user_info[:user][:last_name]
      });
    end

    if test? || (reference || request_options[:admin] || credit_card.valid?)
      gw = get_gateway
      
      
      information = {
        :order_id => request_options[:order_id],
        :customer => user_info[:user][:user_id].to_s + ": " + user_info[:user][:first_name].to_s + " " + user_info[:user][:last_name].to_s,
        :billing_address => {
          :name => user_info[:user][:first_name].to_s + " " + user_info[:user][:last_name].to_s,
          :address1 => user_info[:billing_address][:address],
          :city => user_info[:billing_address][:city],
          :state => user_info[:billing_address][:state],
          :zip => user_info[:billing_address][:zip],
          :country => 'US', # user_info[:billing_address][:country], # TODO: Switch to iso3166 Code - http://www.iso.org/iso/coun-try_codes/iso_3166_code_lists/english_country_names_and_code_elements.htm
          :phone => user_info[:billing_address][:phone],
        }, 
        :email => user_info[:user][:email],
        :customer_ip => request_options[:ip_address],
        :ip => request_options[:ip_address]
      }
      
       information[:card_code] = parameters[:cvc] unless reference

      
      begin 
        response = gw.send(:authorize,amount * 100,reference ? reference : credit_card,information)
      rescue ActiveMerchant::ActiveMerchantError => e
        raise Shop::ShopOrderTransaction::TransactionError.new(e.message)
      end
      
      
      Shop::ShopOrderTransaction::TransactionResponse.new(
                  response.success?,
                  response.authorization,
                  response.message,
                  response.params,
                  response.test?
                )
    else
      Shop::ShopOrderTransaction::TransactionResponse.new(
                  false,
                  nil,
                  parameters[:type] == 'reference' ? 'Invalid Reference' : 'Invalid Credit Card',
                  {},
                  gw.test?
                )
    end  
    
  end
  
  
  def self.sanitize(payment_info)
    payment_info.slice(:card_type,:exp_year)
  end
  
  def payment_record(transaction,payment_info,options = {})
    payment_opts = get_transaction_options(payment_info)
    admin = options[:admin] ? true : false
    if payment_info[:type].to_s == 'reference'
      [admin ? 'admin_reference' : 'reference',nil,transaction.reference ]
    else
      if payment_info[:remember].to_i == 1
        card = payment_opts.card_type_display.to_s + (" ending with %s" /  payment_opts.cc[-4..-1])
        [ admin ? 'admin_remember' : 'remember', card , transaction.reference ]
      else
        [ admin ? 'admin' : 'standard', nil, transaction.reference ]
      end
    end
  end
  
  
  protected
  
  def standard_transaction(currency = nil,&block)
    gw = get_gateway
    
    if currency && currency != 'USD'
      return Shop::ShopOrderTransaction::TransactionResponse.new(false,nil,'Invalid Currency',{},gw.test?)
    end 
    
    begin 
      response = yield(gw)
    rescue ActiveMerchant::ActiveMerchantError => e
      raise Shop::ShopOrderTransaction::TransactionError.new(e.message)
    end
    
    Shop::ShopOrderTransaction::TransactionResponse.new(
                response.success?,
                response.authorization,
                response.message,
                response.params,
                response.test?
              )
  
  end
  
  
end
