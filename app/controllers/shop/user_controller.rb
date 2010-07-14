

class Shop::UserController < ParagraphController

  editor_header 'Shop Paragraphs'
  
  editor_for :orders, :name => "User Orders List", :feature => :shop_user_orders
  editor_for :order_detail, :name => "User Order Detail", :feature => :shop_user_order_detail, :inputs => [[ :page, 'Order ID', :path ]]

  class OrdersOptions < HashModel
    attributes :detail_page_id => nil
    
    page_options :detail_page_id
  end
  class OrderDetailOptions < HashModel
    attributes :list_page_id => nil
    
    page_options :list_page_id
  end

end
