

class Shop::UserRenderer < ParagraphRenderer

  features '/shop/user_feature'

  paragraph :orders
  paragraph :order_detail

  def orders
    @options = paragraph_options(:orders)
    @page_data,@orders = Shop::ShopOrder.paginate(params[:page],
            :conditions => ['end_user_id=? AND state NOT IN ("initial","pending","payment_declined") ',myself.id ],:order => 'ordered_at DESC')
  
    data = { :orders => @orders, :pages => @page_data, :detail_url => @options.detail_page_url }
    
    render_paragraph :text => shop_user_orders_feature(data)
  end
  
  def order_detail
    @options = paragraph_options(:order)
    
    conn_type,conn_id = page_connection
    if editor?
      @order = Shop::ShopOrder.find(:first)
    elsif conn_type == :page
      @order = Shop::ShopOrder.find_by_id(conn_id,:conditions => {:end_user_id => myself.id },
                      :include => { :shop_order_shipments => :order_items })
      set_title("Order #" + @order.id.to_s)
    else
      @order= nil
    end
    
    data = { :order => @order, :list_url => @options.list_page_url}
    
    render_paragraph :text => shop_user_order_detail_feature(data)
  end


end
