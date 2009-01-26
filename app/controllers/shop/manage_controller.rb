
class Shop::ManageController < ModuleController
  
  permit 'shop_manage'

  component_info 'Shop'
  
  
   include ActiveTable::Controller   
   active_table :order_table,
                Shop::ShopOrder,
                [ ActiveTable::IconHeader.new('', :width=>10),
                  ActiveTable::NumberHeader.new('shop_orders.id',:label=>'Order #'),
                  ActiveTable::StringHeader.new('shop_orders.name', :label => 'Ordered By'),
                  ActiveTable::DateHeader.new('ordered_at',:datetime => true),
                  ActiveTable::DateHeader.new('shipped_at', :datetime => true),
                  ActiveTable::OptionHeader.new('state',:options => :order_states),
                  ActiveTable::NumberHeader.new('total')
                ]
                
  protected
  
  def order_states
    Shop::ShopOrder.state_select_options
  end 
  
  public

  def order_table(display=true)
    @active_table_output = order_table_generate params, :order => 'ordered_at DESC', :conditions =>  [ 'state != "pending"' ]
    
    render :partial => 'order_table' if display
  
  end

  def index 
     cms_page_info [ ["Content",url_for(:controller => '/content') ], "Shop" ], "content"
  
     order_table(false)
  end


  def order
     @order = Shop::ShopOrder.find(params[:path][0])
     cms_page_info [ ["Content",url_for(:controller => '/content') ], ["Shop",url_for(:action => 'index') ], ['View Order %s',nil,@order.number ] ], "content"
     
     
  end
  
  def capture_order
    @order = Shop::ShopOrder.find(params[:order_id])
    
    @ship_order = params[:ship].to_i == 1
    @notes = params[:notes]
    
    if request.post? && params[:capture]
      # Capture it
      # Update the order page with a message at the top
      cap = @order.admin_capture_payment(myself,@notes)
      if cap && cap.success?
        if @ship_order
          @order.admin_ship_order(myself,'[Automatic: Capture & Ship]'.t )
          @order.reload
          flash.now[:order_info] = sprintf("Order %s has been captured and marked as shipped".t,@order.number)
        else
          @order.reload
          flash.now[:order_info] = sprintf("Order %s has been captured".t,@order.number)
        end
        @successful = true
      else
        @message = cap ? cap.message : 'Transaction could not be completed at this time'.t
      end
      @transaction_partial = 'capture_order'
      render :partial => 'update_order'
      return
    end
    render :partial => 'capture_order'
  end
  
  def ship_order
    @order = Shop::ShopOrder.find(params[:order_id])
    @notes = params[:notes]
    if request.post? && params['ship']
      if @order.state == 'paid'
        @order.admin_ship_order(myself,@notes)
        @order.reload
        flash.now[:order_info] = sprintf("Order %s has been shipped".t,@order.number)
        @successful = true
      end
      @transaction_partial = 'update_order'
      render :partial => 'update_order'
      return
    end
    
    render :partial => 'ship_order'
  end
  
  def void_order
     @order = Shop::ShopOrder.find(params[:order_id])
     @notes = params[:notes]
     if request.post? && params['void']
      if @order.state == 'authorized'
        voided = @order.admin_void_order(myself,@notes)
        @order.reload
        if voided && voided.success?
          flash.now[:order_info] = sprintf("Order %s has been voided".t,@order.number)
          @successful = true
        else
          @message = voided ? voided.message : 'Transaction could not be completed at this time'.t
        end
      end
      @transaction_partial = 'void_order'
      render :partial => 'update_order'
      return
    end

    render :partial => 'void_order'
  end
  
  
  def refund_order
    @order = Shop::ShopOrder.find(params[:order_id])
    
    @full_refund = params[:full] == '1' ? true : false
    @refund_amount = params[:amount].to_f
    
    @valid_refund = @order.refundable? && (@full_refund || @refund_amount > 0.0)
    
    if @refund_amount > @order.total
      @refund_amount = 0.0
      @full_refund = true
    end 
    
    @notes = params[:notes]
    
    if request.post? && params[:refund]
      if @valid_refund 
        if @full_refund
          @refund_amount = @order.total
        end
        refunded = @order.admin_refund_order(@refund_amount,myself,@notes)
        if refunded && refunded.success?
          flash.now[:order_info] = sprintf("Order %s has been refunded".t,@order.number)
          @successful = true
        else
          @message = refunded ? refunded.message : 'Transaction could not be completed at this time'.t
        end
      end
      @transaction_partial = 'refund_order'
      render :partial => 'update_order'
      return
    end
    
    render :partial => 'refund_order'
  end

end
