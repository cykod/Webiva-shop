
class Shop::ManageUserController < ModuleController
  
  permit 'shop_manage'

  component_info 'Shop'

  include Shop::CartUtility
  
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
                  hdr(:number,'total')
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
    session[:shop_user_checkout] ||= {}
    session[:shop_user_checkout][@cart_id] ||= {}
    
    action_setup
    get_order_processor
   
    render :partial => 'view'
  end   
  
  def add_product
    action_setup
    
    product = Shop::ShopProduct.find_by_id(params[:product_id])
    
    @cart.add_product(product,1)
    @cart.validate_cart!

    get_order_processor 
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

    get_order_processor 
    shipping_options
    
    render :partial => 'user_order'
  end
  
  
  def checkout
    action_setup
  
    @payment_processors = Shop::ShopPaymentProcessor.find(:all,:conditions => ['currency = ?',@currency])
    @payment = params[:payment] || {}

    get_order_processor 

    shipping_options
    if params[:payment]
      if @order_processor.validate_payment(false,@payment,params[:order]||{}) && @order_processor.process_payment
        if @order = @order_processor.process_transaction(request.remote_ip)
          @order.order_items.each do |oi|
            oi.quantity.times do
              opts = oi.order_item.cart_post_processing(@user,oi,{})
            end
          end
          render :partial => 'payment_successful'
          return
        end
      end
      @errors = @order_processor.errors
      @message = @order_processor.transaction_message
    end
    
    render :partial => 'payment'
  end
  
  protected
  
  def action_setup
    @mod = get_module
    @currency = @mod.currency || 'USD'  
    
    @user = EndUser.find_by_id(params[:path][0]) unless @user
    @cart_id =params[:cart_id] unless @cart_id
    @cart = get_cart
  end


  def get_order_processor
    @order_processor = Shop::OrderProcessor.new(@user,session[:shop_user_checkout][@cart_id],@cart)
    @order_processor.admin_order = true
  end
  
  def shipping_options
    @order_processor.set_order_address(true)
    if @order_processor.shippable 
      @order_processor.validate_payment(false,params[:payment],params[:order])
      @order_processor.calculate_shipping(params[:shipping_id]) if params[:shipping_id]

      @shipping_options = @order_processor.shipping_options
      @current_shipping = @order_processor.shipping_category
      @current_shipping_obj = @shipping_options.detect { |itm| itm[1] == @current_shipping } if @shipping_options
    else
      @shipping_options = [['Please add a shipping address to charge shipping',nil]]
    end
  end
  
  def get_cart
    Shop::ShopSessionCart.new(session[:user_carts][@cart_id],@currency,@user)
  end
  
  
  
  
end
