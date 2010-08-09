class Shop::ShopRevenueWidget < Dashboard::WidgetBase


  widget :revenue, :name => "Shop Revenue List", :title => "Shop Revenue List", :permission => :shop_editor
  def script_path ; '/components/shop/javascripts'; end
  def revenue

    set_title_link url_for(:controller => 'shop/manage')
    set_icon 'shop_icon.png'
    require_js 'raphael/raphael-min.js'
    require_js 'raphael/g.raphael.js'

    require_js "raphael/g.bar.js"
    fetch_data

    return render_widget :text => 'Must reload widget to activate.'.t if first?
    render_widget :partial => '/shop/widgets/revenue', :locals => {:totals => @order_total, :dates => @order_dates, :entries => @order_total.length}
  end

  def fetch_data
    beg_week = Date.tomorrow-5
    end_week = Date.tomorrow
    orders = Shop::ShopOrder.sum(:total, :group => "DATE(ordered_at)", :conditions => ['ordered_at between ? and ?',beg_week,end_week])
    @order_total,@order_dates = []

    date_range = ((beg_week..end_week-1).to_a).map { |d| d.to_s }
    dates = Hash[*date_range.collect { |v| [v, 0] }.flatten]

    order_data = dates.merge(orders)

    o = order_data.to_a
    order_dates,@order_total = o.map { |i|  i[0] }, o.map {|i|  i[1] }

    @order_dates= order_dates.map do |t| 
      Date.strptime(str=t).to_s(:short)
    end

    return @order_dates,@order_total
  end


  class RevenueOptions < HashModel
  end
end
