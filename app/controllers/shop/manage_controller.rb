require 'csv'

class Shop::ManageController < ModuleController
  
  permit 'shop_manage'

  component_info 'Shop'
  
  
   include ActiveTable::Controller   
   active_table :order_table,
                Shop::ShopOrder,
                [ :check,
                  hdr(:number,'shop_orders.id',:label=>'Order #'),
                  hdr(:string,'shop_orders.name', :label => 'Ordered By'),
                  hdr(:date_range,'ordered_at'),
                  hdr(:date_range,'shipped_at'),
                  hdr(:option,'state',:options => :order_states),
                  hdr(:number,:total),
                  'Action'
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

  def download
    @tbl = order_table_generate( { :page => 1 }, :order => 'ordered_at DESC',  :conditions =>  [ 'state != "pending"' ], :include => :order_items , :all => true)

    output = ''
    CSV::Writer.generate(output) do |csv|
      csv << [ 'Order ID','Order State', 'Name','Email','Link','Gift','Ordered At','Shipped At','Shipping Adr.','Shp.Line 2', 'Shp.City',
               'Shp.State','Shp.Zip','Billing Adr.','Bil.City','Bil.State','Bil.Zip','Bil.State','Subtotal','Tax','Shipping','Total',
               'Item SKU','Item','Details','Unit Cost','Quantity','Subtotal' ]

      @tbl.data.each do |order|
        order.shipping_address ||= {}
        order.billing_address ||= {}
        csv << [ order.id,
                 order.state_display,
                 order.name,
                 order.end_user ? order.end_user.email : '',
                 url_for(:action => 'order',:path => [ order.id ]),
                 order.gift_order? ? 'Y' : 'N',
                 order.ordered_at.strftime(DEFAULT_DATETIME_FORMAT),
                 order.shipped_at ? order.shipped_at.strftime(DEFAULT_DATETIME_FORMAT) : '',
                 order.shipping_address[:address],
                 order.shipping_address[:address_2],
                 order.shipping_address[:city],
                 order.shipping_address[:state],
                 order.shipping_address[:zip],
                 order.billing_address[:address],
                 order.billing_address[:address_2],
                 order.billing_address[:city],
                 order.billing_address[:state],
                 order.billing_address[:zip],
                 order.display_subtotal,
                 order.display_tax,
                 order.display_shipping,
                 order.display_total
               ]
        order.order_items.each do |item|
          csv << [ order.id,'','','','','','','','','','','','','','','','','','','','','',
                   item.item_sku,
                   item.item_name,
                   item.item_details,
                   item.display_unit_price,
                   item.quantity,
                   item.subtotal
                 ]
        end
                
      end

    end
    
    
    send_data(output,
      :stream => true,
      :type => "text/csv",
              :disposition => 'attachment',
              :filename => sprintf("orders_%s.csv",Time.now.strftime("%Y_%m_%d"))
	    )
    
  end
  
  def capture_order
    @order = Shop::ShopOrder.find(params[:order_id])
    
    @ship_order = params[:ship].to_i == 1
    @notes = params[:notes]
    
    @table = params[:table]
    
    if @ship_order
      @shipment = Shop::ShopOrderShipment.new(:shop_carrier_id =>  @order.shop_shipping_category ? @order.shop_shipping_category.shop_carrier_id : nil, :notify_customer => true )
    end
    
    if request.post? && params[:capture]
      # Capture it
      # Update the order page with a message at the top
      cap = @order.admin_capture_payment(myself,@notes)
      if cap && cap.success?
        if @ship_order
          @order.admin_ship_order(myself,'[Automatic: Capture & Ship]'.t,nil,params[:shipment] || {})
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
      order_table(false) if @table
      render :partial => 'update_order'
      return
    end
    render :partial => 'capture_order'
  end
  
  def ship_order
    @order = Shop::ShopOrder.find(params[:order_id])
    @notes = params[:notes]
    
    @table = params[:table]
    
    @shipment = Shop::ShopOrderShipment.new(:shop_carrier_id =>  @order.shop_shipping_category ? @order.shop_shipping_category.shop_carrier_id : nil, :notify_customer => true)
        
    
    if request.post? && params['ship']
      if @order.state == 'paid'
        @order.admin_ship_order(myself,@notes,nil,params[:shipment])
        @order.reload
        flash.now[:order_info] = sprintf("Order %s has been shipped".t,@order.number)
        @successful = true
      end
      order_table(false) if @table
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
       voided = @order.admin_void_order(myself,@notes)
       @order.reload
       if voided && voided.success?
         flash.now[:order_info] = sprintf("Order %s has been voided".t,@order.number)
         @successful = true
       else
         @message = voided ? voided.message : 'Transaction could not be completed at this time'.t
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
        @refund_amount = @order.total if @full_refund 
        refunded = @order.admin_refund_order(@refund_amount,myself,@notes)
        if refunded && refunded.success?
          flash.now[:order_info] = sprintf("Order %s has been refunded".t,@order.number)
          @successful = true
          @valid_refund=true
        end
      end
      if !@valid_refund
        @message = refunded ? refunded.message : 'Transaction could not be completed at this time'.t
      end
      @transaction_partial = 'refund_order'
      render :partial => 'update_order'
      return
    end
    
    render :partial => 'refund_order'
  end
  
  def add_note
    @order = Shop::ShopOrder.find(params[:order_id])
    
    if request.post? && params[:note] && !params[:note][:note].blank?
       @order.admin_note(myself,params[:note][:note])
       render :action => 'add_note' 
    else
      render :nothing => true
    end      
  end
  
end
