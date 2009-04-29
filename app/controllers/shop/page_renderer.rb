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
  

  def self.get_module
    mod = SiteModule.get_module('shop')
    
    mod.options ||= {}
    mod.options[:field] ||= []
    mod.options[:options] ||= {}
    
    mod
  end

 

  def product_listing

    options = paragraph.data || {}

    display_string = "#{paragraph.id}_#{myself.user_class_id}"
    
    if request.post? && params["shop#{paragraph.id}"]
      if handle_shop_action(params["shop#{paragraph.id}"])
        if options[:cart_page_id].to_i > 0
          flash[:shop_continue_shopping_url] = paragraph_page_url
          redirect_paragraph :site_node => options[:cart_page_id]        
        else
          redirect_paragraph :page
        end
        return
      end
    end    

   if editor?
      category = Shop::ShopCategory.find_by_id(options[:base_category_id].to_i)
      category_id = category.id if category
      category_title = category.name if category
    else
      category_connection,category_link = page_connection()

      target_string = "#{category_connection}_#{category_link}"
      
      category_id,category_title,feature_output = DataCache.get_content("ShopCategory",target_string,display_string) unless flash[:shop_product_added] || request.post? || params[:search]

      unless feature_output
        if category_link.to_i == 0
          category = Shop::ShopCategory.find_by_id(options[:base_category_id].to_i)
        else
          category = Shop::ShopCategory.find_by_id(category_link)
        end
        category_id = category.id if category
      end

    end
    
    unless category
      render_paragraph :inline => 'Invalid Category'.t
      return
    end

    if category_id || params[:search]
      set_page_connection(:content_id, [ 'Shop::ShopCategory',category_id ] )
      set_page_connection(:shop_category_id, category_id)
    end

    set_title(category_title)


    if !feature_output 
      get_module 
      options = paragraph.data || {}
      detail_page =  SiteNode.get_node_path(options[:detail_page],'#')
      detail_page += "/" + (category_id || '0').to_s if options[:include_category].to_s == 'yes'
      
      
      items_per_page = options[:items_per_page] || 10
      currency = @mod.currency
      
      if params[:search]
        search = params[:search]
        pages,products = Shop::ShopProduct.run_search(params[:search],params[:page])
        search_url = "?search=#{CGI::escape(search)}"
        pages[:path] = search_url
      end
      
      data = { :pages => pages, :products => products, :category => category, :detail_page => detail_page, :items_per_page => items_per_page, :currency => currency, :paragraph_id => paragraph.id, :search => search, :page => params[:page], :search_url => search_url}
      
      if flash[:shop_product_added]
        data[:product_added] = flash[:shop_product_added]
      end

      feature_output = shop_product_listing_feature(data)

      DataCache.put_content("ShopCategory",target_string,display_string,feature_output) unless editor?  || params[:search]
    end
    
    require_css('gallery')

    render_paragraph :text => feature_output
  end

  
  def product_detail
    options = paragraph.data || {}
    
    display_string = "#{paragraph.id}_#{myself.user_class_id}"

    if request.post? && params["shop#{paragraph.id}"]
      if handle_shop_action(params["shop#{paragraph.id}"])
        if options[:cart_page_id].to_i > 0
          flash[:shop_continue_shopping_url] = paragraph_page_url
          redirect_paragraph :site_node => options[:cart_page_id]        
        else
          redirect_paragraph :page
        end
        return
      end
    end

    @caching_active = false # !editor? && !flash[:shop_product_added]

    if options[:product_id].to_i > 0
      target_string = "product_#{options[:product_id]}"

      product_id,product_name,feature_output = DataCache.get_content("ShopProduct",target_string,display_string) if @caching_active

      if !feature_output
        product = Shop::ShopProduct.find(options[:product_id])
        product_id = product.id if product
        product_name = product.name
      end
    elsif editor?
      product = Shop::ShopProduct.find(:first)
      product_id = product.id if product
      product_name = product.name if product
    else
      product_connection,product_link = page_connection(:input)

      target_string = "#{product_connection}_#{product_link}"
      
      product_id,product_name,feature_output = DataCache.get_content("ShopProduct",target_string,display_string) if @caching_active

      unless feature_output
        product = Shop::ShopProduct.find_by_id(product_link, :include => [ { :shop_product_options =>  :variation_option }, { :shop_product_class =>  :shop_variations }])
        product_id = product.id if product
        product_name = product.name if product
      end

    end

    if product_id
      set_page_connection(:content_id, [ 'Shop::ShopProduct',product_id ] )
      set_page_connection(:product_id, product_id )
    end


    set_title(product_name)
      
    if !feature_output
      @mod = get_module
      currency = @mod.currency

      data = { :product => product, :currency => currency, :paragraph_id => paragraph.id, :user => myself }
      
      if options[:list_page_id].to_i > 0
        data[:list_page] = SiteNode.get_node_path(options[:list_page_id])
        cat_conn_type,cat_conn_id = page_connection(:category)
        
        data[:list_page] << "/#{cat_conn_id}" if !cat_conn_id.blank?
        data[:list_page] << "?search=#{CGI::escape(params[:search])}" if params[:search]
      end

      if flash[:shop_product_added]
        data[:product_added] = flash[:shop_product_added]
      end

      feature_output = shop_product_detail_feature(data)

      DataCache.put_content("ShopProduct",target_string,display_string, [  product_id,product_name,feature_output ]) if @caching_active
    end
    
    require_css('gallery')

    render_paragraph :text => feature_output
  end


 

  def display_cart
    options = paragraph.data || {}

    cart = get_cart

    full_cart_page =  SiteNode.get_node_path(options[:full_cart_page_id],'#')
    @mod = get_module
      
    currency = @mod.currency
    data = { :cart=> get_cart, :full_cart_page => full_cart_page, :currency => currency, :user => myself }
    feature_output = display_cart_feature(data)
    render_paragraph :text => feature_output
  end

  include Editor::MenuRenderer::MenuFeature

  def category_listing
    opts = Shop::PageController::CategoryListingOptions.new(paragraph.data||{})
    
    page = SiteNode.get_node_path(opts.list_page_id)
    
    if !page || !opts.base_category_id
      render_paragraph :text => 'Configure Paragraph'.t
      return
    end
    
    category_connection,category_link = page_connection()
    if(category_link) 
      @selected_category_id = category_link
    end
    
    selected_categories = []
    selected_categories << Shop::ShopCategory.find_by_id(@selected_category_id)
    while selected_categories[-1] && selected_categories[-1].parent_id > 0
      selected_categories << Shop::ShopCategory.find_by_id(selected_categories[-1].parent_id)
    end
    selected_categories = [] if selected_categories[-1] && selected_categories[-1].parent_id == 0
    
    @selected_categories = selected_categories.compact.map(&:id)
    @page_url = page
    
    categories = Shop::ShopCategory.find(:all,:conditions => ['parent_id = ?',opts.base_category_id])
    
    depth = opts.depth - 1
    
    
    menu = category_data(categories,depth)
    
    request_path = "/" + (params[:full_path]||[]).join("/")
    
    data = { :url =>  request_path,
             :menu => menu
           }
           
    data[:edit] = true if editor?
           
    render_paragraph :text => menu_feature(get_feature('menu', :class_name => 'Editor::MenuRenderer'),data)
  end
  
  def category_data(categories,depth)
   categories.collect do |cat|
      { :title => cat.name,
	      :link => @page_url + "/" + cat.id.to_s,
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
      @selected_category_id = category_link
    end
      
    selected_category =  Shop::ShopCategory.find_by_id(@selected_category_id)
    category_list = [  ] 
    category_list << selected_category  if selected_category && selected_category.parent_id > 0
    while category_list[0] && category_list[0].parent_id > 0
      parent_cat = Shop::ShopCategory.find_by_id(category_list[0].parent_id)
      if !parent_cat || parent_cat.id == opts.base_category_id
        break
      else
        category_list.unshift(parent_cat)
      end
    end
    category_list.compact!
  
    child_categories = selected_category.children if selected_category
    
    
    data = { :categories => category_list, :child_categories => child_categories, :page_url => page, :selected_category => selected_category }
    
    render_paragraph :text => shop_page_category_breadcrumbs_feature(data)
  end

  feature :shop_page_search_bar, :default_feature => <<-FEATURE
    <cms:search>
    Search: <cms:field/><cms:button>Search</cms:button>
    </cms:search>
  FEATURE

  def shop_page_search_bar_feature(data)
    webiva_feature(:shop_page_search_bar) do |c|
      c.define_tag('search') { |t| "<form action='?' method='post'  >" + t.expand + "</form>" }
        c.define_tag('field') { |t| tag(:input,t.attr.merge({:type => 'text', :class => 'text_field', :name => 'run_search', :value => vh(data[:search]) })) }
        c.define_button_tag('button')
    end
  end

  def search_bar
    if request.post? &&  params[:run_search]
      @options = paragraph_options(:search_bar)
      
      path = SiteNode.node_path(@options.search_page_id)
      redirect_paragraph path + "?search=" + CGI.escape(params[:run_search])
      return
    end
    
    search_obj = DefaultsHashObject.new(:field => params[:search])
    data = { :search => params[:search] }
     
    render_paragraph :text => shop_page_search_bar_feature(data)
  end

  protected

  def handle_shop_action(act)

    @cart = get_cart

    case act[:action]
    when 'add_to_cart':
      prd = Shop::ShopProduct.find_by_id(act[:product])
      return false unless prd
      options = { :variations => {}}
      prd.option_variations.each do |variation|
        option_id = act[:variation][variation.id.to_s]
        option = variation.options.find_by_id(option_id)
        return false unless option
        options[:variations][variation.id] = option.id
      end
      paragraph_action('Add to Cart: %s' / prd.name)
      @cart.add_product(prd,(act[:quantity] || 1).to_i,options)
      flash[:shop_product_added] = prd.id
      @cart.validate_cart!

      return true
    end
  end
  
  include Shop::CartUtility # Get Cart Functionality
  
  
end
