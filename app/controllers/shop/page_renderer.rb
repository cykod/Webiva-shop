require 'yaml'


class Shop::PageRenderer < ParagraphRenderer

  module_renderer
  
  paragraph :product_listing
  paragraph :product_detail
  paragraph :category_listing
  paragraph :display_cart
  paragraph :category_breadcrumbs
  paragraph :search_bar
  
  features '/shop/page_feature'
  features '/editor/menu_feature'

  def product_listing

    options = paragraph_options(:product_listing)

    return if handle_shop_action(options,params["shop#{paragraph.id}"])

    # if we have a detail link connection, don't display the category paragraph
    detail_connection, detail_link = page_connection(:detail)
    return render_paragraph :nothing => true if !detail_link.blank?

    category_connection,category_link = page_connection(:input)

    if category_link.blank?
      category = Shop::ShopCategory.find_by_id(options.base_category_id.to_i)
    else
      category = Shop::ShopCategory.find_by_url(category_link)
    end

    unless category
      render_paragraph :text => 'Invalid Category'.t
      return
    end

    target_string = "#{category.id}_#{myself.user_class_id}"
      
    result = renderer_cache(Shop::ShopProduct,target_string,
                              :skip =>  flash[:shop_product_added] || 
                                        request.post? || 
                                        params[:search] ) do |cache|
       cache[:category_id] = category.id
       cache[:category_url] = category.url
       cache[:cache_title] = category.name

       get_module 
       detail_page =  options.detail_page_url

      
       items_per_page = options.items_per_page || 10
       currency = @mod.currency

       if params[:search]
         search = params[:search]
         pages,products = Shop::ShopProduct.run_search(options.shop_shop_id,params[:search],params[:page])
         search_url = "?search=#{CGI::escape(search)}"
         pages[:path] = search_url
       end

       data = { :pages => pages, :products => products, :category => category, :detail_page => detail_page, :items_per_page => items_per_page, :currency => currency, :paragraph_id => paragraph.id, :search => search, :page => params[:page], :search_url => search_url, :options => options}

       if flash[:shop_product_added]
         data[:product_added] = flash[:shop_product_added]
       end

       cache[:feature_output] = shop_product_listing_feature(data)         
    end

    if result.category_id || params[:search]
      set_page_connection(:content_id, [ 'Shop::ShopCategory',result.category_id ] )
      set_page_connection(:shop_category_id, result.category_id)
    end

    set_title(result.category_title)

    require_css('gallery')

    render_paragraph :text => result.feature_output
  end

  
  def product_detail
    options = paragraph_options(:product_detail)

    return if handle_shop_action(options,params["shop#{paragraph.id}"])

    product_connection,product_link = page_connection(:input)

    # If we have a category connection and aren't displaying a product,
    # let the listing paragraph have this one
    category_connection, category_link = page_connection(:category)
    if !category_connection.blank? &&  !options.product_id && product_link.blank?
      return  render_paragraph :nothing => true
    end

    @skip_caching = flash[:shop_product_added]

    if options.product_id.to_i > 0
      cache_object = [ Shop::ShopProduct, options.product_id ]
    elsif editor?
      cache_object = nil
    else 
      cache_object = [ Shop::ShopProduct, product_link ]
    end

    result = renderer_cache(cache_object,"#{myself.user_class_id}",:skip => @skip_caching) do |cache|
      find_args = { :include => [ { :shop_product_options =>  :variation_option }, { :shop_product_class =>  :shop_variations }], :conditions => { :shop_shop_id => options.shop_shop_id } }
      if editor?
        product = Shop::ShopProduct.find(:first,find_args)
      elsif cache_object[1].is_a?(Integer)
        product = Shop::ShopProduct.find_by_id(cache_object[1],find_args)
      else
        product = Shop::ShopProduct.find_by_url(cache_object[1],find_args)
      end

      if product
        cache[:product_id] = product.id
        cache[:product_name] = product.name
        cache[:content_node_id] = product.content_node.id
      end

      @mod = get_module
      currency = @mod.currency

      data = { :product => product, :currency => currency, :paragraph_id => paragraph.id, :user => myself }

      if options.list_page_url
        data[:list_page] = options.list_page_url
        if product 
          category = Shop::ShopCategory.find_by_url(category_link) if category_link 
          if !category || category.parent_id == 0
            category = product.deepest_category
          end
          if category && category.parent_id > 0
            data[:category] = category
            data[:list_page] << "/#{category.url}" 
          end
        end
        data[:list_page] << "?search=#{CGI::escape(params[:search])}" if params[:search]
      end

      if flash[:shop_product_added]
        data[:product_added] = flash[:shop_product_added]
      end

      cache[:output] = shop_product_detail_feature(data)
    end


    if result.product_id
      set_page_connection(:content_id, [ 'Shop::ShopProduct',result.product_id ] )
      set_page_connection(:product_id, result.product_id )
      set_content_node(result.content_node_id)
    end

    set_title(result.product_name) if result.product_name
    require_css('gallery')
    render_paragraph :text => result.output
  end


 

  def display_cart
    options = paragraph_options(:display_cart)

    cart = get_cart

    full_cart_page =  SiteNode.get_node_path(options.full_cart_page_id,'#')
    @mod = get_module
      
    currency = @mod.currency
    data = { :cart=> get_cart, :full_cart_page => full_cart_page, :currency => currency, :user => myself }
    render_paragraph :text => shop_display_cart_feature(data)
  end


  def category_listing
    opts = paragraph_options(:category_listing)
    
    page = opts.list_page_url
    
    if !page || !opts.base_category_id
      render_paragraph :text => 'Configure Paragraph'.t
      return
    end
    
    category_connection,category_link = page_connection()
    if(category_link) 
      @selected_category_url = category_link
    end
    

    result = renderer_cache(Shop::ShopCategory,category_link) do |cache|
      selected_categories = []
      selected_categories << Shop::ShopCategory.find_by_url(@selected_category_url)
      while selected_categories[-1] && selected_categories[-1].parent_id > 0
        selected_categories << Shop::ShopCategory.find_by_id(selected_categories[-1].parent_id)
      end
      @selected_categories = selected_categories.compact.map(&:id)

      @page_url = page

      categories = Shop::ShopCategory.find(:all,:conditions => ['parent_id = ?',opts.base_category_id])

      depth = opts.depth - 1

      menu = category_data(categories,depth)
      request_path = "/" + (params[:full_path]||[]).join("/")
      data = { :url =>  request_path, :menu => menu }
      data[:edit] = true if editor?

      cache[:output] = menu_feature(data)
    end

    render_paragraph :text => result.output
  end
  
  def category_data(categories,depth)
   categories.collect do |cat|
      { :title => cat.name,
	      :link => @page_url + "/" + cat.url.to_s,
	      :description => cat.description,
	      :selected => @selected_categories.include?(cat.id),
	      :menu => depth > 1 ? category_data(cat.children,depth-1) : nil }
    end
  end


  def category_breadcrumbs
  
    opts = paragraph_options(:category_breadcrumbs)
    page = SiteNode.get_node_path(opts.list_page_id)
    
    if !page || !opts.base_category_id
      render_paragraph :text => 'Configure Paragraph'.t
      return
    end
    
    category_connection,category_link = page_connection()
    if(category_link) 
      @selected_category_url = category_link
    end
      
    result = renderer_cache(["Shop::ShopCategory", category_link]) do |cache|
      selected_category =  Shop::ShopCategory.find_by_url(@selected_category_url)
      if selected_category
        category_list = selected_category.parent_list(opts.base_category_id)
        child_categories = selected_category.children
      end

      data = { :categories => category_list, :child_categories => child_categories, :page_url => page, :selected_category => selected_category }
      cache[:output] = shop_page_category_breadcrumbs_feature(data)
    end

    render_paragraph :text => result.output 
  end


  def search_bar
    if request.post? &&  params[:run_search]
      @options = paragraph_options(:search_bar)
      
      redirect_paragraph @options.search_page_url + "?search=" + CGI.escape(params[:run_search])
      return
    end
    
    search_obj = DefaultsHashObject.new(:field => params[:search])
    data = { :search => params[:search] }
     
    render_paragraph :text => shop_page_search_bar_feature(data)
  end

  protected

  def handle_shop_action(options,act)

    if request.post? && params["shop#{paragraph.id}"]

      @cart = get_cart

      case act[:action]
      when 'add_to_cart':
        prd = Shop::ShopProduct.find_by_id(act[:product],:conditions => { :shop_shop_id => options.shop_shop_id })
        return false unless prd
        product_options = { :variations => {}}
        if prd.option_variations.length > 0 
          # TODO: Redirect to Detail page with message
          return false unless act[:variation]
        end
        prd.option_variations.each do |variation|
          option_id = act[:variation][variation.id.to_s]
          option = variation.options.find_by_id(option_id)
          return false unless option
          product_options[:variations][variation.id] = option.id
        end
        paragraph_action('Add to Cart: %s' / prd.name)
        @cart.add_product(prd,(act[:quantity] || 1).to_i,product_options)
        flash[:shop_product_added] = prd.id
        @cart.validate_cart!

        if options.cart_page_id.to_i > 0
          flash[:shop_continue_shopping_url] = paragraph_page_url
          return redirect_paragraph :site_node => options.cart_page_id        
        else
          return redirect_paragraph :page
        end
        return true
      end
    end

    return false

  end
  
  include Shop::CartUtility # Get Cart Functionality
  
  
end
