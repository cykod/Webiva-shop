class Shop::PaypalExpressPaymentProcessor < Shop::PaymentProcessor

  def self.shop_payment_processor_handler_info
    { 
      :currencies => ['USD','EUR', 'CHF' ],
      :type => 'Paypal',
      :name => "Paypal Express Payment Processor"
    }
  end

  def self.get_options(hsh)
     Shop::PaypalExpressPaymentProcessor::ProcessorOptions.new(hsh)
  end
  
  class ProcessorOptions < HashModel
    attributes :login => nil, :password => nil, :test_server => 'test', :signature => nil,
      :page_style => nil, :header_image_id => nil, :header_background_color => nil,
      :header_border_color => nil, :background_color => nil

    domain_file_options :header_image_id

    validates_presence_of :login, :password,:signature

    validates_format_of :header_background_color, :with => /^[0-9a-fA-F]{6}$/, :allow_blank => true
    validates_format_of :header_border_color, :with => /^[0-9a-fA-F]{6}$/, :allow_blank => true
    validates_format_of :background_color, :with => /^[0-9a-fA-F]{6}$/, :allow_blank => true
  end
    
  def get_gateway 
      ActiveMerchant::Billing::Base.gateway_mode = @options[:test_server] == 'test' ? :test : :live
      ActiveMerchant::Billing::PaypalExpressGateway.new(
              :login => @options[:login],
              :password => @options[:password],
              :test => (@options[:test_server] == 'test'),
              :signature => @options[:signature])
          
  end
  
  def self.options_partial
    '/shop/config/paypal_express_options'
  end
  
  def self.validate_options(opts)
    opts.valid?
  end
  
  def self.transaction_partial
    "/shop/config/paypal_express_form"
  end

  def test?
    @options[:test_server] != 'live'
  end

  def can_authorize_payment?
    false
  end

  def offsite?
    true
  end

  def offsite_redirect_url(order, remote_ip, return_url, cancel_url)
    gw = self.get_gateway

    purchase_options = self.paypal_purchase_options(order)
    purchase_options.merge! self.paypal_customize_payment_page
    purchase_options.merge! :ip => remote_ip, :return_url => return_url, :cancel_return_url => cancel_url

    response = gw.setup_purchase order.total * 100, purchase_options

    raise Shop::ShopOrderTransaction::TransactionError.new(response.message) unless response.success?

    gw.redirect_url_for response.token
  end

  def payment_record(transaction,payment_info,options = {})
    [ 'standard', transaction.params['transaction_id'], '' ]
  end

  def format_authorization(auth)
    auth
  end

  def purchase(parameters,currency,amount,user_info,request_options = {})
    gw = get_gateway
    
    details_response = gw.details_for(request_options[:parameters][:token])

    details_transaction = Shop::ShopOrderTransaction::TransactionResponse.new(
      details_response.success?,
      details_response.authorization,
      details_response.message,
      details_response.params,
      details_response.test?
    )

    return details_transaction unless details_response.success?

    response = gw.purchase(amount*100,
                           :ip => request_options[:remote_ip],
                           :payer_id => request_options[:parameters]['PayerID'],
                           :token => request_options[:parameters][:token],
                           :currency => currency
                           )

    Shop::ShopOrderTransaction::TransactionResponse.new(
      response.success?,
      response.authorization,
      response.message,
      details_transaction.params.merge(response.params),
      response.test?
    )
  end

  def capture(authorization,currency,amount)
    raise Shop::ShopOrderTransaction::TransactionError.new('Capture not supported')
  end

  def credit(authorization,currency,amount)
    return standard_transaction(currency) do |gw|
      response = gw.credit(amount * 100,format_authorization(authorization),:currency => currency)
    end
  end

  def void(authorization)
    raise Shop::ShopOrderTransaction::TransactionError.new('Void not supported')
  end

  def authorize(parameters,currency,amount,user_info,request_options = {})
    raise Shop::ShopOrderTransaction::TransactionError.new('Authorize not supported')
  end

  def paypal_purchase_options(order)
    if order.shipping_address && ! order.shipping_address.empty?
      {
        :shipping_address => self.paypal_shipping_address(order),
        :address_override => true,
        :order_id => order.id,
        :currency => order.currency
      }
    else
      {
        :order_id => order.id,
        :currency => order.currency,
        :no_shipping => true
      }
    end
  end

  def paypal_shipping_address(order)
    # found this in active_merchant/billing/gateways/paypal/paypal_common_api.rb add_address()
    {
      :name => order.end_user.name,
      :address1 => order.shipping_address[:address],
      :address2 => order.shipping_address[:address_2],
      :city => order.shipping_address[:city],
      :state => order.shipping_address[:state],
      :country => order.shipping_address[:country],
      :zip => order.shipping_address[:zip]
    }
  end

  def paypal_customize_payment_page
    gw_options = self.class.get_options @options
    # found this in active_merchant/billing/gateways/paypal_express.rb build_setup_request()
    {
      :page_style => @options[:page_style], # name
      :header_image => gw_options.header_image ? gw_options.header_image.full_url.sub(/^http:/, 'https:') : '', # url
      :header_background_color => @options[:header_background_color], # color 6 hex digits
      :header_border_color => @options[:header_border_color], # color 6 hex digits
      :background_color => @options[:background_color] # color 6 hex digits
    }
  end

  protected
  
  def standard_transaction(currency = nil,&block)
    gw = get_gateway
    
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
