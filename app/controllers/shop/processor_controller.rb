class Shop::ProcessorController < ParagraphController
  
  editor_header "Shop Paragraphs"
  editor_for :checkout, :name => 'Shop Checkout',
                    :inputs => [ [ :checkout_page, 'Page Path', :path ] ], :feature => 'shop_checkout',
                    :triggers => [['Successful Order','action']]

  editor_for :full_cart, :name => 'Full Page Shopping Cart', :feature => 'shop_full_cart'

  user_actions [ :update_shipping_country, :update_billing_country ]
  
  
  class FullCartOptions < HashModel
    attributes :checkout_page_id => nil, :show_coupons => false

    validates_presence_of :checkout_page_id
    
    page_options :checkout_page_id
  end


  class CheckoutOptions < HashModel
    attributes :cart_page_id => nil, :success_page_id => nil, :receipt_template_id => nil, :show_company => false, :show_fax => false, :address_type => 'american', :show_gift => false, :add_tags => '', :cart_site_feature_id => nil, :guest_allowed => true
    
    boolean_options :show_fax, :show_company, :show_gift, :guest_allowed
    integer_options :receipt_template_id
    page_options :cart_page_id, :success_page_id
  end
  
  def update_shipping_country
   @country = Shop::ShopRegionCountry.find(:first,:conditions => ['country = ?',params[:country] ], :include => :region )
   @state_info = @country.generate_state_info(params[:state]) if @country
   @state_info ||= {:selected =>  params[:state] }
   render :partial => 'update_shipping'    
  end

 def update_billing_country
   @country = Shop::ShopRegionCountry.find(:first,:conditions => ['country = ?',params[:country] ], :include => :region )
    @state_info = @country.generate_state_info(params[:state]) if @country
    @state_info ||= {:selected =>  params[:state] }
    render :partial => 'update_billing'    
  end
    

end
