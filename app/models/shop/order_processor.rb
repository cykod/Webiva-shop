
class Shop::OrderProcessor
  
  attr_reader :user,:cart,:shippable,:errors,:order
  attr_reader :shipping_options,:payment_processors,:payment,:transaction_message
  attr_accessor :admin_order

  def initialize(user,order_session_info,cart)
    @user = user
    @order_state = order_session_info
    @cart = cart
    @shippable = cart.shippable?
  end

  def verify_page(page)
    page = 'address' if page.blank? || !%w(success processing payment address login).include?(page)
    page = 'processing' if @order_state[:stage] != 'success' && page == 'success'
    page = 'payment' if @order_state[:stage] != 'processing' && page == 'processing'

    if(page == 'payment')
      if @cart.shippable?
        page = 'address' if !@user.billing_address || !@user.shipping_address
      else
        page = 'address' if !@user.billing_address
      end
      @order_state[:stage] = 'payment' if page == 'payment'
    end

    if(page == 'address')
      page = 'login' if !@user.id 
    end

    page
  end

  ### Order address processing ###
  def adr(adr_type=:shipping)
    @order_state[:address] ||= {}
    @order_state[:address][adr_type]
  end

  def add_automatic_coupons
     Shop::ShopCoupon.automatic_coupons(@cart).each { |coupon| @cart.add_product(coupon,1,nil) }
  end

  def valid_cart?
   @cart.validate_cart!
   @cart.products_count != 0
  end
 

  def register_order_user(args)
    @end_user = EndUser.new()
    @existing_user = EndUser.push_target(args[:email],:no_register => true)
    @end_user = @existing_user if @existing_user

    @end_user.attributes = args.slice(:email,:password,:password_confirmation,:first_name,:last_name)

    @end_user.registered = true if !@end_user.password.blank? || !@end_user.password_confirmation.blank? 
    @end_user.user_level = @end_user.registered ? 3 : 2 
    @end_user.user_class_id = UserClass.default_user_class_id

    @end_user.valid?
    @end_user.validate_registration({ :first_name => 'required', :last_name => 'required'} )
    @end_user
  end

  # Address Processing
  #
  def shipping_address
    @shipping_address ||= adr(:shipping) ? user.build_shipping_address(adr(:shipping)) : user.current_shipping_address
  end

  def billing_address
    @billing_address ||= adr(:billing) ?  user.build_billing_address(adr(:billing)) : user.current_billing_address
  end

  def user_same_address(same_adr,posted_data)
    if @shippable
      if posted_data
        @same_address = same_adr
      else
        @same_address = shipping_address.compare(billing_address)
      end
    else
      @same_address = false
    end
  end

  attr_reader :same_address

  def update_addresses(shipping_args,billing_args,address_type = 'us')
    self.shipping_address.attributes = shipping_args
    self.billing_address.attributes = @same_address ? shipping_args : billing_args
   
    if @shippable 
      shipping_address.validate_registration(:shipping,true,address_type) 
      Shop::ShopRegion.validate_country_and_state(shipping_address) unless self.admin_order
    end

    unless @same_address
      billing_address.validate_registration(:billing,true,address_type) 
      Shop::ShopRegion.validate_country_and_state(billing_address) unless self.admin_order
    end

    if shipping_address.errors.empty? && billing_address.errors.empty?
      shipping_address.end_user_id = @user.id
      shipping_address.save if @shippable

      billing_address.end_user_id = @user.id
      billing_address.save
      if user.billing_address_id != billing_address.id || 
         (@shippable && user.shipping_address_id != shipping_address.id)
        user.billing_address_id =billing_address.id
        user.shipping_address_id = shipping_address.id if @shippable
        user.save
      end
      set_order_address(true)
      true
    end
  end

  def selected_country(adr_type = :shipping)
    Shop::ShopRegionCountry.find_by_country(adr_type == :shipping ? shipping_address.country : billing_address.country)
  end

  def state_information(adr_type = :shipping)
    country = selected_country(adr_type)
    if country
      country.generate_state_info(adr_type == :shipping ? shipping_address.state : billing_address.state)
    else
      {}
    end
  end
  
  def set_order_address(force=false)
    if(force || !adr(:billing))
      @order_state[:address] = {  :shipping => shipping_address.attributes.clone.symbolize_keys!, 
                            :billing => billing_address.attributes.clone.symbolize_keys! }

    end
  end
    
  ### Order Payment Processing ###

  def validate_payment(processing,payment_info,order_info)
    @payment = payment_info || {}

    calculate_destination
    return false if !@country && !self.admin_order

    @payment_processors = Shop::ShopPaymentProcessor.find(:all,:conditions => ['currency = ?',@cart.currency])
      
    if @order_state[:order_id] 
      @order = Shop::ShopOrder.find(:first, :conditions => ['id=? AND end_user_id=?  AND state IN("pending","payment_declined")', @order_state[:order_id],user.id ])
    end
    
    if !@order 
      @order_state[:order_id] = nil
      @order = Shop::ShopOrder.new(:end_user_id => user.id)
    end

    @order.attributes = order_info.symbolize_keys.slice(:gift_order,:gift_message)  if order_info

    if @shippable && @shipping_info
      @payment[:shipping_category] ||= @shipping_info[0][:category].id if @shipping_info && @shipping_info[0]
      @payment[:shipping_category] = @payment[:shipping_category].to_i
    end

    @cart.shipping = calculate_shipping(@payment[:shipping_category])
    @cart.tax = calculate_tax

    @order_state[:total] = @cart.total unless processing

    true
   end

   def shipping_category
     @payment[:shipping_category]
   end

   def active_order?
      @order = Shop::ShopOrder.find(:first, :conditions => ['id=? AND end_user_id=?  AND state IN("pending","payment_declined")', @order_state[:order_id],user.id ])
    end
    
  
  def process_payment
    if !@order  || !@order.id
      @order ||= Shop::ShopOrder.new(:end_user_id => user.id)
      @order.save
      @order_state[:order_id] = @order.id


    end

    @order_state[:payment_info] = @payment

#    if @order_state[:total] && @order_state[:total] != @cart.total
#       @errors = [ "Your cart has been updated, please reverify your total" ]
#       return false
#    end

    # Find the ShopPaymentProcessor
    if @cart.total == 0
      @shop_processor = Shop::ShopPaymentProcessor.free_payment_processor
    else
      @shop_processor = Shop::ShopPaymentProcessor.find_by_id(@payment[:selected_processor_id])
    end

    return false if !@shop_processor

    if @shop_processor && !@shop_processor.test?
      errors = @shop_processor.validate_payment_options(@user,@payment[@payment[:selected_processor_id]],adr(:billing))
    end

    if(errors)
      @errors = errors
      false
    else
      # Save order information to the order

      @order.pending_payment(
                             :shipping_address => adr(:shipping),
                             :billing_address => adr(:billing),
                             :shop_payment_processor => @shop_processor,
                             :shop_shipping_category_id => @payment[:shipping_category],
                             :user => @user,
                             :cart => @cart,
                             :payment => @payment[@payment[:selected_processor_id]]
                            )
                            true
    end
  end

  def offsite?
    @order.offsite?
  end

  def offsite_redirect_url(remote_ip, return_url, cancel_url)
    @order.offsite_redirect_url remote_ip, return_url, cancel_url
  end

  def process_transaction(remote_ip, params=nil)
    transaction = @order.authorize_payment(:remote_ip => remote_ip, :parameters => params, :admin => self.admin_order)
    if transaction.success?
      @order_state[:stage] = 'success'
      @order_state[:order_id] = nil
      @order_state[:shop_user_id] = nil

      if Shop::AdminController.module_options.auto_capture
        @order.capture_payment
      end

      return @order
    else
      @transaction_message = transaction.message
      false
    end

  end

  def email_data
    { :ORDER_ID => @order.id,
      :ORDER_HTML => @order.format_order_html,
      :ORDER_TEXT => @order.format_order_text,
      :ORDER_BILLING_COUNTRY  => (@order.billing_address[:country]).to_s ,
      :ORDER_BILLING_NAME     => (@order.billing_address[:address_name]).to_s ,
      :ORDER_BILLING_ZIP      => (@order.billing_address[:zip]).to_s ,
      :ORDER_BILLING_ADDRESS  => (@order.billing_address[:address]).to_s ,
      :ORDER_BILLING_CITY     => (@order.billing_address[:city]).to_s ,
      :ORDER_BILLING_STATE    => (@order.billing_address[:state]).to_s ,
      :ORDER_BILLING_ADDRESS2 => (@order.billing_address[:address_2]).to_s
    }
  end
  
  def calculate_shipping(shipping_category_id = nil)
    if @shipping_info
      @payment ||= {}
      @payment[:shipping_category] = shipping_category_id.to_i
      current_shipping = @shipping_info.detect { |elm| elm[:category].id == @payment[:shipping_category] }
      cart.shipping = current_shipping[:shipping] if current_shipping
    else
      cart.shipping = 0.0
    end
  end

  def calculate_tax
    if @country
      cart.tax = @country.calculate_tax(cart, self.shippable ? self.shipping_address : self.billing_address)
    end
  end

  def calculate_destination
    if @shippable
      # Get shipping options - find the region we are shipping to
      @country = Shop::ShopRegionCountry.locate(adr[:country])
      if @country
        @shipping_info = @country.shipping_details(@cart)
        @shipping_options = @country.shipping_options(@cart.currency,@shipping_info)
      end
    else
      @country = Shop::ShopRegionCountry.locate(adr(:billing)[:country])
      @shipping_options = []
      @shipping_info = nil
    end
  end
end
