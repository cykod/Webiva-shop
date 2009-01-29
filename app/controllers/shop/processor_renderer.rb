class Shop::ProcessorRenderer < ParagraphRenderer

  module_renderer
  
  paragraph :full_cart
  paragraph :checkout
  

 def get_module
    @mod = Shop::PageRenderer.get_module
    @mod.options ||= {}
    @mod.options[:field] ||= []
    @mod.options[:options] ||= {}
    @mod.options[:currency] = @mod.options[:shop_currency]
    @mod
  end  

  feature :full_cart, :default_feature => <<-FEATURE
    <cms:no_cart>
    You currently have no products in your shopping cart
    </cms:no_cart>
    <cms:cart>
    <table>
    <thead>
      <tr><th>Product</th><th>Unit Cost</th><th>Quantity</th><th>Cost</th></tr>
    </thead>
    <tbody>
    <cms:products>
      <cms:product>
      <tr>
          <td><b><cms:name/></b><br/><cms:details/></td>
          <td><cms:unit_cost/></td>
          <td><cms:quantity/></td>
          <td><cms:product_cost/></td>
      </tr>
      </cms:product>
    <tr>
      <td colspan='3' align='right'><cms:update_quantity>Update Quantity</cms:update_quantity></td>
    </tr>
    <tr>
      <td colspan='3' align='right'>Total:</td>
      <td><cms:total/></td>
    </tr>
    </cms:products>
    <tr>
      <td colspan='2' align='left'><cms:continue_shopping>Continue Shopping</cms:continue_shopping></td>
      <td colspan='2' align='right'><cms:checkout>Checkout</cms:checkout></td>
    </tr>
    </table>
    </cms:cart>
  FEATURE
      
 
def full_cart_feature(feature,data)


   parser_context = FeatureContext.new do |c|
   
      c.define_tag 'user' do |tag|
        myself.name
      end

      c.define_tag 'no_cart' do |tag|
        data[:cart].products_count > 0 ? nil : tag.expand
      end
      c.define_tag 'cart' do |tag|
        data[:cart].products_count > 0 ? tag.expand : nil
      end

      c.define_tag 'cart:products' do |tag|
        <<-EOTAG
         <form action='' method='post'>
               <input type='hidden' name='shop#{data[:paragraph_id]}[action]' value='update_quantities'/>
          #{tag.expand}
          </form>
        EOTAG
      end

      c.define_tag 'cart:product' do |tag|
        cnt = data[:cart].products_count
        result = ''
        data[:cart].products.each_with_index do |cart_product,index|
           
           tag.locals.cart_item = cart_product
           tag.locals.quantity = cart_product.quantity
           tag.locals.first = index == 0
           tag.locals.last = index == (cnt-1)
           result << tag.expand
        end

        result
      end

      define_position_tags(c,'cart:product')
      
      c.define_expansion_tag('static') { |tag| data[:static] }
      c.define_tag('not_static') { |tag| data[:static] }
      c.define_value_tag('cart:product:name') { |tag|  tag.locals.cart_item.name }
      c.define_value_tag('cart:product:details') { |tag| tag.locals.cart_item.details }

      c.define_tag 'cart:product:unit_cost' do |tag|
        Shop::ShopProductPrice.localized_amount(tag.locals.cart_item.price(data[:currency]),data[:currency])

      end
      c.define_tag 'cart:product:quantity' do |tag|
        if data[:static]
          tag.locals.quantity
        else
          size=tag.attr['size'] || 4
          # Need to create an hash for the options and the item as we may not have an id
          # if this is a session situation
          item_hash,opt_hash = quantity_hash(tag.locals.cart_item)
          classname=tag.attr['class'] || 'quantity_field'
          "<input class='#{classname}' name='shop#{data[:paragraph_id]}[quantity][#{item_hash}][#{opt_hash}]' type='text' value='#{vh tag.locals.quantity}' size='#{size}' />"
        end
      end
      c.define_tag 'cart:product:product_cost' do |tag|
        price = tag.locals.cart_item.price(data[:currency]) * tag.locals.cart_item.quantity
        Shop::ShopProductPrice.localized_amount(price,data[:currency])
      end

      c.define_tag 'cart:total' do |tag|
        Shop::ShopProductPrice.localized_amount(data[:cart].total(data[:currency]),data[:currency])
      end
      
      c.expansion_tag('cart:shippable') { |t| data[:cart].shippable? }
      c.define_tag 'cart:shipping' do |tag|
        if data[:cart].shippable?
          data[:cart].shipping ? Shop::ShopProductPrice.localized_amount(data[:cart].shipping,data[:currency]) : "(Next Step)"
        else
          Shop::ShopProductPrice.localized_amount(0.0,data[:currency])
        end
      end

      c.define_submit_tag 'cart:products:update_quantity' do |tag|
        !data[:static]
      end
      

      define_submit_tag(c,'cart:checkout',:default => 'Checkout'.t,:form => data[:checkout_page])
      
      c.define_submit_tag 'cart:continue_shopping',:default => 'Continue Shopping'.t,:form => session[:shop_continue_shopping_url_link] do |tag|
        session[:shop_continue_shopping_url_link]
      end
   end
   parse_feature(feature,parser_context)
  end

  # Generate a unit hash of a cart item's options
  # for use in the cart form
  def quantity_hash(cart_item)
    cart_item.quantity_hash
 
  end

  def full_cart
    options = paragraph.data || {}

  
    # Keep the continue shopping link it we stay on this page
    if flash[:shop_continue_shopping_url]
      session[:shop_continue_shopping_url_link] = flash[:shop_continue_shopping_url]
    elsif !request.post?
      session[:shop_continue_shopping_url_link] = nil
    end


    if !editor? && request.post? && params["shop#{paragraph.id}"]
      if handle_shop_action(params["shop#{paragraph.id}"])
          flash[:shop_continue_shopping_url]  = session[:shop_continue_shopping_url_link]
          redirect_paragraph :page
        return
      end
    end


    @mod =  Shop::AdminController.module_options
    currency = @mod.shop_currency

    cart = get_cart
    cart.validate_cart!

    checkout_page =  SiteNode.get_node_path(options[:checkout_page_id],'#')
 
       
    data = { :cart=> cart, :checkout_page => checkout_page, :currency => currency, :paragraph_id => paragraph.id }

    feature_output = full_cart_feature(get_feature('full_cart'),data)
    
    render_paragraph :text => feature_output

  end  
  

  def checkout

    # Check which page we are on 
    checkout_connection,checkout_link = page_connection()

    page = verify_page(checkout_link)

    # Check that we have a valid cart
    cart = get_cart
    
    cart.validate_cart!
    
    if cart.products_count == 0 && !editor? && page != 'success'
      return invalid_cart_page
    end


    require_js('prototype.js');

    @mod = get_module
    currency = @mod.options[:shop_currency] || 'USD'

    data = { :cart=> get_cart, :checkout_page => nil, :currency => currency, :static => true}

    session[:shop_continue_shopping_url_link] = nil
    @feature_output = full_cart_feature(get_feature('full_cart'),data) unless page == 'payment'
    


    case page
    when 'success': success_page()
    when 'processing': processing_page()
    when 'payment': payment_page()
    when 'address': address_page()
    when 'login': login_page()
    else 
      render_paragraph :text => 'Invalid Checkout Page:'.t  + page.to_s
    end
  end

  protected

  # Perform state machine checking and kick 
  # page back to the current page
  def verify_page(page)
    session[:shop] ||= {}
    
    @cart = get_cart

    page = 'address' if page.blank? || !%w(success processing payment address login).include?(page)
    
    if(page == 'success')
       page = 'processing' if session[:shop][:stage] != 'success'
    end

    if(page == 'processing')
       page = 'payment' if session[:shop][:stage] != 'processing'
    end
    
    if(page == 'payment')
      session[:shop][:stage] = 'payment'
      if @cart.shippable?
        page = 'address' if !myself.billing_address || !myself.shipping_address
      else
        page = 'address' if !myself.billing_address
      end
    end

    if(page == 'address')
      if !myself.id || !myself.registered?
        page = 'login'
      end
    end

    page
  end

  def invalid_cart_page
    render_paragraph :text => 'Your cart is currently empty'.t

  end

  def login_page
    @end_user = EndUser.new()
    @login = EndUser.new(params[:login])
    

    if request.post? 
      if params[:login]
        user = EndUser.login_by_email(params[:login][:email],params[:login][:password])
        if user
          session[:user_id] = user.id
          session[:user_model] = user.class.to_s
          myself
          redirect_paragraph site_node.node_path + "/address"
          return
        else
          @invalid_login = true
        end

      elsif params[:register]
        # White list only a subset of the user fields
        values = {}
        %w(email password password_confirmation first_name last_name).each { |fld| values[fld] = params[:register][fld] }
        @end_user.attributes = values

        @end_user.registered = true
        @end_user.user_level = 3
        @end_user.user_class_id = UserClass.default_user_class_id

        all_valid = true 
        @end_user.valid?
        @end_user.validate_registration({ :first_name => 'required', :last_name => 'required'} )
        all_valid = false unless @end_user.errors.empty?
      
        if all_valid
          @end_user.save
          session[:user_model] = 'EndUser'
          session[:user_id] = @end_user.id
          redirect_paragraph site_node.node_path + "/address"
          return
        end
      end
    end
    render_paragraph :partial => '/shop/processor/login', :locals => {:user => @end_user, :login => @login, :invalid_login => @invalid_login, :feature_output => @feature_output }

  end

  def address_page
    shipping_address = myself.shipping_address  || EndUserAddress.new(:address_name => 'Shipping Address'.t)
    billing_address = myself.billing_address || EndUserAddress.new(:address_name => 'Billing Address'.t)

    cart = get_cart 
    shippable = cart.shippable?


    @same_address = params[:same_address]

    if request.post? && (params[:shipping_address] || params[:billing_address])
      
      shipping_address.attributes = params[:shipping_address]

      billing_address.attributes = @same_address ? params[:shipping_address] : params[:billing_address]

      shipping_address.end_user_id= myself.id # end_user_id is attr_protected
      billing_address.end_user_id = myself.id

      shipping_address.validate_registration(:shipping,true)  if shippable
      billing_address.validate_registration(:billing,true) unless @same_address
      
      Shop::ShopRegion.validate_country_and_state(shipping_address)  if shippable
      Shop::ShopRegion.validate_country_and_state(billing_address) unless @same_address
      
      if shipping_address.errors.empty? && billing_address.errors.empty?
        shipping_address.save if shippable
        billing_address.save
        myself.update_attributes(:billing_address_id => billing_address.id, :shipping_address_id => shipping_address.id)
        session[:shop] ||= {}
        session[:shop][:address] = { :shipping => shipping_address.attributes.clone.symbolize_keys!, 
                                     :billing => billing_address.attributes.clone.symbolize_keys! }
        redirect_paragraph site_node.node_path + "/payment"
        return
      end
    end
    
    countries = [['--Select Country--','']] + Shop::ShopRegionCountry.find(:all,:order => 'country').collect { |cnt| [ cnt.country.t,cnt.country ] }.sort { |a,b| a[0] <=> b[0] }

    shipping_address.first_name = myself.first_name if shipping_address.first_name.blank?
    shipping_address.last_name= myself.last_name if shipping_address.last_name.blank?
    billing_address.first_name = myself.first_name if billing_address.first_name.blank?
    billing_address.last_name= myself.last_name if billing_address.last_name.blank?
    
    if !request.post? && shipping_address.compare(billing_address)
      @same_address = true
    end
    
    shipping_selected_country = Shop::ShopRegionCountry.find_by_country(shipping_address.country)
    shipping_state_info = shipping_selected_country ? shipping_selected_country.generate_state_info(shipping_address.state) : {}

    billing_selected_country = Shop::ShopRegionCountry.find_by_country(billing_address.country)
    billing_state_info = billing_selected_country ? billing_selected_country.generate_state_info(billing_address.state) : {}

    render_paragraph :partial => '/shop/processor/address', :locals => { :shipping_address => shipping_address, :billing_address => billing_address, :same_address => @same_address, :countries => countries, :shipping_state_info => shipping_state_info,
    :billing_state_info => billing_state_info, :feature_output => @feature_output, :cart => cart}

  end

  def payment_page

    session[:shop] ||= {}
    unless session[:shop][:address]
      session[:shop][:address] = { :shipping => myself.shipping_address.attributes.clone.symbolize_keys!,
                            :billing => myself.billing_address.attributes.clone.symbolize_keys! }
                            
    end
    unless session[:shop][:order]
      # Save the cart in the session
    end
    
    get_module


    cart = get_cart 
    shippable = cart.shippable?
    

    currency = @mod.options[:shop_currency] || 'USD'
    
    if shippable
      

      # Get shipping options - find the region we are shipping to
      country = Shop::ShopRegionCountry.locate(session[:shop][:address][:shipping][:country]) 
      
      if !country
        redirect_paragraph site_node.node_path + "/address"
        return
      end
      
      shipping_info = country.shipping_details(cart)
      shipping_options = country.shipping_options(currency,shipping_info)
      
     
    else
      shipping_options = []
    end
    
    payment_processors = Shop::ShopPaymentProcessor.find(:all,:conditions => ['currency = ?',currency])
      
    # for each payment processor
      # make sure they accept payment in the designated regions

    if session[:shop][:order_id] # @payment[:order_id] && session[:shop][:order_id] == @payment[:order_id].to_i
      @order = Shop::ShopOrder.find(:first, :conditions => ['id=? AND end_user_id=?  AND state IN("pending","payment_declined")', session[:shop][:order_id],myself.id ])
    end
      
    @payment = params[:payment] || (@order ? @order.payment_information : {}) || {}
    
    if flash[:shop_message]
      @payment = session[:shop][:payment_info] if session[:shop][:payment_info]
    end
    
    @payment[:shipping_category] ||= shipping_info[0][0].id if shipping_info && shipping_info[0] && shipping_info[0][0].id
    @payment[:shipping_category] = @payment[:shipping_category].to_i
    
    if shipping_info
      current_shipping = shipping_info.detect { |elm| elm[0].id == @payment[:shipping_category] }
      cart.shipping = current_shipping[1] if current_shipping
    else
      cart.shipping = 0.0
    end
    
    cart_data = { :cart=> cart, :checkout_page => nil, :currency => currency, :static => true}    
    @feature_output = full_cart_feature(get_feature('full_cart'),cart_data)
    
    if request.post? && params[:payment] && !(params[:update].to_i > 0)
    
      
      unless @order
        @order = Shop::ShopOrder.create(:end_user_id => myself.id)
        session[:shop][:order_id] = @order.id
      end
      
      session[:shop][:payment_info] = @payment
      
      
      # Validate the total is the same as we sent out
        # if not add error -> Your cart has been updated, please verify it's contents
      
      # Validate that we have a shipping category
      tax = 0.0 # calculate_tax
      shipping = cart.shipping # calculate_shipping

      # Find the ShopPaymentProcessor
      shop_processor = Shop::ShopPaymentProcessor.find_by_id(@payment[:selected_processor_id])
      
      unless shop_processor.test?
        errors = shop_processor.validate_payment_options(myself,@payment[@payment[:selected_processor_id]],session[:shop][:address][:billing])
      end
      
      if(errors)
        # Show errors
        # raise errors.inspect
      else
        # Save order information to the order

        @order.pending_payment( :currency => currency,
                                :tax => tax,
                                :shipping => shipping,
                                :shipping_address => session[:shop][:address][:shipping],
                                :billing_address => session[:shop][:address][:billing],
                                :shop_payment_processor => shop_processor,
                                :shop_shipping_category_id => @payment[:shipping_category],
                                :user => myself,
                                :cart => cart,
                                :payment => @payment[@payment[:selected_processor_id]]
                              )
        
      
        # Set Refresh Header
        headers['Refresh'] = '1; URL=' + site_node.node_path + "/processing"

        session[:shop][:stage] = 'processing'
        
        # Render a processing paragraph
        render_paragraph :partial => "/shop/processor/processing"
        return 
      end
    end



    render_paragraph :partial => '/shop/processor/payment', :locals => { :shipping_address => session[:shop][:address][:shipping], :billing_address => session[:shop][:address][:billing], :cart => cart, :shipping_options => shipping_options, :payment => @payment, :currency => currency,
      :payment_processors => payment_processors, :message => flash[:shop_message], :address_page => site_node.node_path + "/address",
      :feature_output => @feature_output, :shippable => cart.shippable?, :errors => errors }

  end

  def processing_page
  
    if session[:shop][:order_id]
       page_redirect = nil
       @order = Shop::ShopOrder.find(:first,:conditions => ['id = ? AND end_user_id = ? AND state IN("pending","payment_declined")',session[:shop][:order_id],myself.id])
       transaction = @order.authorize_payment(:remote_ip => request.remote_ip )  if @order
        if @order && transaction.success?
            get_cart.clear
            @order.order_items.each do |oi|
              oi.quantity.times do
                opts = oi.order_item.cart_post_processing(myself,oi,session)
                if opts.is_a?(Hash) && opts[:redirect]
                  page_redirect = opts[:redirect] 
                end
              end
            end
            session[:shop][:stage] = 'success'
            session[:shop][:order_id] = nil
            
            if page_redirect
              redirect_paragraph page_redirect
            else
              redirect_paragraph site_node.node_path + "/success"
            end
        else
          flash[:shop_message] = transaction.message if @order

          redirect_paragraph site_node.node_path + "/payment"
        end
    else
      redirect_paragraph site_node.node_path + "/payment"
    end
  


  end

  def success_page
    render_paragraph :partial => '/shop/processor/success'


  end

  def get_cart
    if myself.id
      cart = Shop::ShopUserCart.new(myself)

      if session[:shopping_cart]
        cart.transfer_session_cart(Shop::ShopSessionCart.new(session[:shopping_cart]))
        session[:shopping_cart] = nil
      end
      cart
    else
      session[:shopping_cart] ||= []
      Shop::ShopSessionCart.new(session[:shopping_cart])
    end
  end
  
  
 def handle_shop_action(act)

    @cart = get_cart

    case act[:action]
    when 'update_quantities':
      @cart.products.each do |cart_item|
        item_hash,opt_hash = quantity_hash(cart_item)
        if act[:quantity][item_hash] && act[:quantity][item_hash][opt_hash]
          quantity = act[:quantity][item_hash][opt_hash].to_i
          @cart.edit_product(cart_item.item,quantity,cart_item.options)
        end
      end
      @cart = get_cart
      @cart.validate_cart!
      
      flash[:cart_edited] = true
      return true
    end
  end  
  
end
