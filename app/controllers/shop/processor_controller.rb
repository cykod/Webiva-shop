class Shop::ProcessorController < ParagraphController
  
  editor_header "Shop Paragraphs"
  editor_for :checkout, :name => 'Shop Checkout',
                    :inputs => [ [ :checkout_page, 'Page Path', :path ] ], :features => ['full_cart']

  editor_for :full_cart, :name => 'Full Page Shopping Cart', :features => ['full_cart']

  user_actions [ :update_shipping_country, :update_billing_country ]
  
  
  class FullCartOptions < HashModel
    attributes :checkout_page_id => nil, :show_coupons => false

    validates_presence_of :checkout_page_id
    
    page_options :checkout_page_id
  end


  class CheckoutOptions < HashModel
    attributes :cart_page_id => nil, :success_page_id => nil, :receipt_template_id => nil, :show_company => false, :show_fax => false, :address_type => 'american'
    
    boolean_options :show_fax, :show_company
    integer_options :receipt_template_id
    page_options :cart_page_id, :success_page_id
  end
  
  def update_shipping_country
   @country = Shop::ShopRegionCountry.find(:first,:conditions => ['country = ?',params[:country] ], :include => :region )
    if @country
      @state_info = @country.generate_state_info(params[:state]) if @country
      render :partial => 'update_shipping'    
    else
      render :nothing => true
    end
  end

 def update_billing_country
   @country = Shop::ShopRegionCountry.find(:first,:conditions => ['country = ?',params[:country] ], :include => :region )
    if @country
      @state_info = @country.generate_state_info(params[:state]) if @country
      render :partial => 'update_billing'    
    else
      render :nothing => true
    end
  end
    

end
