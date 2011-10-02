class Shop::ProcessorRenderer < ParagraphRenderer

  paragraph :full_cart
  paragraph :checkout
  
  features '/shop/processor_feature'

  include Shop::CartUtility # Get Cart Functionality
  
  # Generate a unit hash of a cart item's options
  # for use in the cart form
  def quantity_hash(cart_item)
    cart_item.quantity_hash
  end
 
  # override myself so we don't need an account
  def myself
    super_myself = controller.send(:myself)
    if !super_myself.id && session[:shop_user_id] 
      @shop_user_only = true
      @shop_myself ||= EndUser.find_by_id(session[:shop_user_id])
      self.visiting_end_user_id = @shop_myself.id if @shop_myself
      return @shop_myself
    else
      super_myself
    end
  end

  def full_cart
  
    options = paragraph_options(:full_cart)

  
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

    @cart = get_cart unless @cart
    Shop::ShopCoupon.automatic_coupons(@cart).each { |coupon| @cart.add_product(coupon,1,nil) }
    
    @cart.validate_cart!

    data = { :cart=> @cart, :checkout_page => options.checkout_page_url, :currency => @mod.currency, :paragraph_id => paragraph.id}
    feature_output = shop_full_cart_feature(data)
    render_paragraph :text => feature_output
  end  
  

  def checkout

    # Find out if we're on a subpage
    checkout_connection,checkout_link = page_connection()

    # Get the current page we're on (validating that we're not further along than we should be)
    @page_name = setup_page(checkout_link)

    # add in any automatic coupons to the cart
    @order_processor.add_automatic_coupons    
    
    # Check that we have a valid cart
    return invalid_cart_page if !@order_processor.valid_cart? && !editor? && @page_name  != 'success'

    require_js('prototype.js');
    @options = paragraph_options(:checkout)

    @feature_output = render_cart() unless @page_name == 'payment'
    

    @feature_data = { :page => @page_name, :order_processor => @order_processor,
                      :cart_feature => @feature_output, :options => @options }

    # Dispatch to the correct page
    valid_pages = %w(success processing payment address login)
    if valid_pages.include?(@page_name)
      self.send("#{@page_name}_page")
    else
      render_paragraph :text => 'Invalid Checkout Page:'.t  + page.to_s
    end
  end

  protected

  # Perform state machine checking and kick 
  # page back to the current page
  def setup_page(page)
    session[:shop] ||= {}
    @cart = get_cart
    @order_processor = Shop::OrderProcessor.new(myself,session[:shop],@cart)
    @order_processor.verify_page(page)    
  end

  # Display a message showing the cart is currently empty
  def invalid_cart_page
    render_paragraph :text => 'Your cart is currently empty'.t

  end

  def login_page
    @login = EndUser.new(params[:login])
    

    if request.post? 
      if params[:login]
        user = EndUser.login_by_email(params[:login][:email],params[:login][:password])
        if user
          process_login(user)
          return redirect_paragraph site_node.node_path + "/address"
        else
          @invalid_login = true
        end

      elsif params[:register]
        @end_user = @order_processor.register_order_user(params[:register])
        if @end_user.errors.empty?
          @end_user.save
          if @end_user.registered?
            process_login(@end_user,false)
          else
            # if it's a temp user - put it in the session
            session[:shop_user_id] = @end_user.id
          end
          redirect_paragraph site_node.node_path + "/address"
          return
        end
      end
    end
    @end_user ||= EndUser.new
 
    @feature_data.merge!({ :user => @end_user, :login => @login,
                        :invalid_login => @invalid_login })

    render_paragraph :text => shop_checkout_feature(@feature_data)
  end

  def address_page
     
    @order_processor.user_same_address(!params[:same_address].blank?,request.post?)

    if request.post? && (params[:shipping_address] || params[:billing_address])
      if @order_processor.update_addresses(params[:shipping_address],
                                        params[:billing_address],
                                        @options.address_type == 'american' ? 'us' : 'eu')
        redirect_paragraph site_node.node_path + "/payment"
        return
      end
    end

    countries = Shop::ShopRegionCountry.full_select_options

    @feature_data.merge!({:countries => countries})
    render_paragraph :text => shop_checkout_feature(@feature_data)
  end


  def payment_page
    @order_processor.set_order_address

    @payment_params = params[:payment]
    if flash[:shop_message]
      @payment_params = session[:shop][:payment_info] if session[:shop][:payment_info]
    end

    if !@order_processor.validate_payment(params[:payment] ? true : false,@payment_params,params[:order]) 
      redirect_paragraph site_node.node_path + "/address"
      return
    end

    if request.post? && (params[:payment] || @order_processor.cart.total <= 0) && !(params[:update].to_i > 0)
      if @order_processor.process_payment
        session[:shop][:stage] = 'processing'

        if @order_processor.offsite?
          begin
            redirect_paragraph @order_processor.offsite_redirect_url request.remote_ip, Configuration.domain_link(site_node.node_path + "/processing"), Configuration.domain_link(site_node.node_path + "/payment")
            return
          rescue Shop::ShopOrderTransaction::TransactionError => e
            flash[:shop_message] = e.message
          end
        else
          # Set Refresh Header which will actually process the transaction
          headers['Refresh'] = '1; URL=' + site_node.node_path + "/processing"
          # Render a processing paragraph
          @feature_data[:page] = 'processing' 
          render_paragraph :text => shop_checkout_feature(@feature_data)
          return
        end
      end
    end

    render_cart # render the cart now, after we have everything calced
    @feature_data.merge!(
          :cart_feature => @feature_output,
          :message => flash[:shop_message],
          :address_page =>  site_node.node_path + "/address",
          :user => myself
    )

    render_paragraph :text => shop_checkout_feature(@feature_data)
  end

  def processing_page
    if @order_processor.active_order?
      if @order = @order_processor.process_transaction(request.remote_ip, params)
        get_cart.clear

        opts = @order.post_process(myself,session)
        if opts.is_a?(Hash) && opts[:redirect]
          page_redirect = opts[:redirect] 
        end

        email_data = @order_processor.email_data
        if @receipt_template = MailTemplate.find_by_id(@options.receipt_template_id.to_i)
          @receipt_template.deliver_to_user(myself,email_data)
        end
        email_data.delete(:ORDER_TEXT)

        self.elevate_user_level myself, EndUser::UserLevel::CONVERSION
        self.set_user_value myself, @order.total

        paragraph_action(myself.action('/shop/processor/purchase', :target => @order))
        paragraph.run_triggered_actions(email_data,'action',myself)

        myself.tag_names_add(@options.add_tags) unless @options.add_tags.blank?

        session[:shop_user_id] = nil
        session[:shopping_cart] = []

        if page_redirect
          redirect_paragraph page_redirect
        else
          if @options.success_page_url
            redirect_paragraph @options.success_page_url
          else
            redirect_paragraph site_node.node_path + "/success"
          end
        end
      else
        flash[:shop_message] = @order_processor.transaction_message
        redirect_paragraph site_node.node_path + "/payment"
      end
    else
      redirect_paragraph site_node.node_path + "/payment"
    end
  end

  def success_page
    render_paragraph :text => shop_checkout_feature(@feature_data)
  end


  def render_cart
    get_module
    data = { :cart=> @cart, :checkout_page => nil, :currency => @mod.currency, :static => true,
      :site_feature_id =>  @options.cart_site_feature_id 
    }

    session[:shop_continue_shopping_url_link] = nil
    @feature_output = shop_full_cart_feature(data) unless @page == 'payment'

  end


  
  def handle_shop_action(act)

    @cart = get_cart

    case act[:action]
    when 'update_quantities':
      if act[:remove]
        @cart.products.each do |cart_item|
          item_hash,opt_hash = quantity_hash(cart_item)
          if act[:remove][item_hash]  && act[:remove][item_hash][opt_hash]
            @cart.edit_product(cart_item.item,0,cart_item.options)
          end
        end
      else
        @cart.products.each do |cart_item|
          item_hash,opt_hash = quantity_hash(cart_item)
          if act[:quantity][item_hash] && act[:quantity][item_hash][opt_hash]
            quantity = act[:quantity][item_hash][opt_hash].to_i
            @cart.edit_product(cart_item.item,quantity,cart_item.options)
          end
        end
      end
      @cart = get_cart
      @cart.validate_cart!
      
      flash[:cart_edited] = true
      return true
    when 'coupon'
      if @coupon = Shop::ShopCoupon.search_coupon(act[:code],@cart)
        @cart.add_product(@coupon,1,nil)
        return true
      end
    end
    false
  end  
  
end
