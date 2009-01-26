class Shop::ProcessorController < ParagraphController
  
  editor_header "Shop Paragraphs"
  editor_for :checkout, :name => 'Shop Checkout',
                    :inputs => [ [ :checkout_page, 'Page Path', :path ] ], :features => ['full_cart']

  editor_for :full_cart, :name => 'Full Page Shopping Cart', :features => ['full_cart']


  def full_cart
    @options = FullCartOptions.new(params[:full_cart] || @paragraph.data)
    return if handle_module_paragraph_update(@options)
    @pages = [['--Please select a page--'.t,'']] + SiteNode.page_options()
  end
  
  class FullCartOptions < HashModel
    default_options :checkout_page_id => nil
    integer_options :checkout_page_id

    validates_presence_of :checkout_page_id
  end



  def checkout
    @options = CheckoutOptions.new(params[:checkout] || @paragraph.data)
    return if handle_module_paragraph_update(@options)
    @pages = [['--Please select a page--'.t,'']] + SiteNode.page_options()
  end
  
  

  class CheckoutOptions < HashModel
    default_options :success_page_id => nil
    integer_options :success_page_id

    validates_presence_of :success_page_id
  end
  
  user_actions [ :update_shipping_country, :update_billing_country ]
  
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
