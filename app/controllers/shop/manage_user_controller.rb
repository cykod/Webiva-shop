
class Shop::ManageUserController < ModuleController
  
  permit 'shop_manage'

  component_info 'Shop'
  
  def self.members_view_handler_info
    { 
      :name => 'Shop',
      :controller => '/shop/manage_user',
      :action => 'view'
    }
   end  
  
 include ActiveTable::Controller   
   active_table :order_table,
                Shop::ShopOrder,
                [ :check,
                  hdr(:number,'shop_orders.id',:label=>'Order #'),
                  hdr(:date,'ordered_at',:datetime => true),
                  hdr(:date,'shipped_at', :datetime => true),
                  hdr(:option,'state',:options => :order_states),
                  hdr(:option,'total')
                ]
                
  protected
  
  def order_states
    Shop::ShopOrder.state_select_options
  end 
  
  public
  
  def display_orders_table(display = true)
    @user = EndUser.find_by_id(params[:path][0]) unless @user
    
    @active_table_output = order_table_generate params, :order => 'ordered_at DESC', :conditions =>  [ 'state != "pending" AND end_user_id=?',@user.id ]
    
    render :partial => 'order_table' if display
  end
  
  def view
    @tab = params[:tab]
    @show = params[:show]
    
    display_orders_table(false)
    
    @cart_id = DomainModel.generate_hash
    session[:user_carts] ||= {}
    session[:user_carts][@cart_id] = []
    
    
    action_setup
    
    render :partial => 'view'
  end   
  
  def add_product
    action_setup
    
    product = Shop::ShopProduct.find_by_id(params[:product_id])
    
    @cart.add_product(product,1)
    @cart.validate_cart!
    
    shipping_options
    
    render :partial => 'user_order'
  
  end
  
  def edit_cart
    action_setup
    
    @cart.products.each do |cart_item|
      item_hash,opt_hash = cart_item.quantity_hash
      if params[:quantity] && params[:quantity][item_hash] && params[:quantity][item_hash][opt_hash]
        quantity = params[:quantity][item_hash][opt_hash].to_i
        @cart.edit_product(cart_item.item,quantity,cart_item.options)
      end
    end
    @cart = get_cart
    @cart.validate_cart!  
    
    shipping_options
    
    render :partial => 'user_order'
  end
  
  
  def checkout
    action_setup
  
    @payment_processors = Shop::ShopPaymentProcessor.find(:all,:conditions => ['currency = ?',@currency])
    @payment = params[:payment] || {}
    
    shipping_options
    if params[:payment]
      session[:user_cart_orders] ||= {}

      if session[:user_cart_orders][@cart_id]
        @order = Shop::ShopOrder.find_by_id_and_end_user_id(session[:user_cart_orders][@cart_id],@user.id)
      end
        
      unless @order
        @order = Shop::ShopOrder.create(:end_user_id => @user.id)
        session[:user_cart_orders][@cart_id] = @order.id
      end
      
      tax = 0.0 # calculate_tax
      shipping = @cart.shipping # calculate_shipping

      # Find the ShopPaymentProcessor
      shop_processor = Shop::ShopPaymentProcessor.find_by_id(@payment[:selected_processor_id])
      
      unless shop_processor.test?
        errors = shop_processor.validate_payment_options(@payment[@payment[:selected_processor_id]],session[:shop][:address][:billing])
      end
      
      if(errors)
        # Show errors
        # raise errors.inspect
      else
        # Save order information to the order
        @order.pending_payment( :currency => @currency,
                                :tax => tax,
                                :shipping => shipping,
                                :shipping_address => (@user.shipping_address ? @user.shipping_address.attributes : {}),
                                :billing_address => (@user.billing_address ? @user.billing_address.attributes : {}),
                                :shop_payment_processor => shop_processor,
                                :shop_shipping_category_id => @shipping_id,
                                :user => @user,
                                :cart => @cart,
                                :admin => true,
                                :payment => @payment[@payment[:selected_processor_id]]
                              )
                              
        transaction = @order.authorize_payment(:remote_ip => request.remote_ip, :admin => true )  if @order
        if @order && transaction.success?
          @order.order_items.each do |oi|
            oi.quantity.times do
              opts = oi.order_item.cart_post_processing(@user,oi,{})
            end
          end
          render :partial => 'payment_successful'
          return
        end
      end
    end
    
    render :partial => 'payment'
  end
  
  protected
  
  def action_setup
    @mod = get_module
    @currency = @mod.options[:currency] || 'USD'  
    
    @user = EndUser.find_by_id(params[:path][0]) unless @user
    @cart_id =params[:cart_id] unless @cart_id
    @cart = get_cart
  
  end
  
  def shipping_options
    if @cart.shippable? 
      if @user.shipping_address
        country = Shop::ShopRegionCountry.locate(@user.shipping_address.country) 
        shipping_info = country.shipping_details(@cart)
        @shipping_options = country.shipping_options(@currency,shipping_info)
        
        @shipping_id = (params[:shipping_id] || @shipping_options[0][1]).to_i
        
        @current_shipping = shipping_info.detect { |elm| elm[0].id == @shipping_id }
        @cart.shipping = @current_shipping[1] if @current_shipping
      else
        @shipping_options = [['Please add a shipping address to charge shipping',nil]]
      end
    end
  end
  
  def get_cart
    Shop::ShopSessionCart.new(session[:user_carts][@cart_id],@user)
  end
  
  
  
  
end
