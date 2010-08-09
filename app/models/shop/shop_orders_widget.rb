class Shop::ShopOrdersWidget < Dashboard::WidgetBase


  widget :orders, :name => "Shop Order List", :title => "Shop Order List", :permission => :shop_editor

  def orders

   set_icon 'shop_icon.png'
    set_title_link url_for(:controller => 'shop/manage')

    @orders = Shop::ShopOrder.find(:all, :include => [:end_user], :conditions => ['state IN (?)',options.state], :limit => options.count)

    render_widget :partial => '/shop/widgets/orders', :locals => { :orders => @orders , :options => options}
  end

  class OrdersOptions < HashModel
    attributes :count => 10, :state => nil
    integer_options :count
    validates_numericality_of :count

    options_form(
      fld(:count, :text_field, :label => "Number orders displayed"),
      fld(:state, :check_boxes, :options => Shop::ShopOrder.state_select_options, 
          :label => "Display order with status", :checked=> true,  :separator => '<br/>')

    )
  end
end
