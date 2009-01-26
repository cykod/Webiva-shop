require 'yaml'


class Shop::PageRenderer < ParagraphRenderer

  module_renderer
  
  paragraph :product_listing
  paragraph :product_detail
  paragraph :category_listing
  paragraph :display_cart
  paragraph :category_breadcrumbs
  paragraph :search_bar

  def get_module
    @mod = Shop::PageRenderer.get_module
    @mod.options ||= {}
    @mod.options[:currency] = @mod.options[:shop_currency]
    @mod
  end

  def self.get_module
    mod = SiteModule.get_module('shop')
    
    mod.options ||= {}
    mod.options[:field] ||= []
    mod.options[:options] ||= {}
    
    mod
  end

  feature :shop_product_listing, :default_feature => <<-FEATURE
    <cms:search>
     <h1>Searching for '<cms:value/>'</h1>
    </cms:search>
    <cms:category>
      <h1><cms:value/></h1>
    </cms:category>
    <cms:featured_products>
     <h1>Featured Products</h1>
    <div class='products'>
      <cms:product>
        <div class='product'>
          <cms:img border='1' size='preview' /><br/>
          <em><cms:name/></em> &nbsp;&nbsp;<b><cms:price/></b><br/>
          <a <cms:href/> >details</a>
        </div>
      </cms:product>
     </div>
     <div class='clear'></div>
      <hr/>
    </cms:featured_products>
    <cms:products>
      <div class='products'>
      <cms:product>
        <div class='product'>
          <cms:img border='1' size='preview' /><br/.
          <em><cms:name/></em> &nbsp;&nbsp;<b><cms:price/></b><br/>
          <a <cms:href/> >details</a>
        </div>
      </cms:product>
      </div>
    <div class='clear'></div>
    </cms:products>
    <div class='product_pages'>
      <cms:pages/>
    </div>
  FEATURE
  
  def product_listing_feature(feature,data)
   parser_context = FeatureContext.new do |c|
   
      c.define_value_tag('search') { |t| h(data[:search]) }
   
      c.define_tag 'product_added' do |tag|
        if data[:product_added] 
          tag.locals.product_added = Shop::ShopProduct.find_by_id(data[:product_added])
          tag.expand
        else
          nil
        end
      end
      
      c.define_tag 'product_added:name' do |tag|
        tag.locals.product_added ? tag.locals.product_added.name : 'Invalid Product'.t
      end   
   
      c.define_value_tag 'category' do |tag|
        !data[:products] && data[:category].id > 1 ? data[:category].name : nil
      end

      c.define_tag 'no_products' do |tag|
        data[:category].shop_category_products.size ==  0 ? nil : tag.expand
      end
      
      c.define_value_tag('count') { |tag|  data[:category].shop_category_products.size  }
      
      c.define_tag 'products' do |tag|
        if data[:products]
          tag.locals.page_data = data[:pages]
          tag.locals.products = data[:products]
          tag.locals.search = true
        else
          tag.locals.search = false
          tag.locals.page_data,products =data[:category].paginate_products(:all, :per_page => data[:items_per_page], :page => data[:page])
          tag.locals.products = products.collect {|cp| cp.shop_product }
        end
        data[:category].shop_category_products.size > 0 ? tag.expand : nil
      end

      c.define_tag 'no_featured_products' do |tag|
        data[:category].featured_shop_category_products.size ==  0 ? nil : tag.expand
      end
      c.define_tag 'featured_products' do |tag|
        if data[:products] 
          nil
        else
          tag.locals.products = data[:category].find_products(:featured).collect {|cp| cp.shop_product }
          data[:category].featured_shop_category_products.size > 0 ? tag.expand : nil
        end
      end
      

      c.define_tag 'no_unfeatured_products' do |tag|
        data[:category].unfeatured_shop_category_products.size ==  0 ? nil : tag.expand
      end
      c.define_tag 'unfeatured_products' do |tag|
        tag.locals.products = data[:category].find_products(:unfeatured).collect {|cp| cp.shop_product }
        data[:category].unfeatured_shop_category_products.size > 0 ? tag.expand : nil
      end


      c.define_tag 'product' do |tag|
        c.each_local_value(tag.locals.products,tag,'product')
      end
      
      c.define_tag 'product:add_to_cart' do |tag|
        if tag.single?
          button = tag.attr['button'] || 'Add to Cart'
          <<-HTML
            <form action='' method='post'>
               <input type='hidden' name='shop#{data[:paragraph_id]}[action]' value='add_to_cart'/>
               <input type='hidden' name='shop#{data[:paragraph_id]}[product]' value='#{tag.locals.product.id}'/>
               <input type='submit' name='go' value='#{vh button}' />
            </form>
          HTML
        else
          <<-HTML
            <form action='' method='post'>
               <input type='hidden' name='shop#{data[:paragraph_id]}[action]' value='add_to_cart'/>
               <input type='hidden' name='shop#{data[:paragraph_id]}[product]' value='#{tag.locals.product.id}'/>
               #{tag.expand}
            </form>
          HTML
        end
      end
      
      c.define_button_tag('product:add_to_cart:button',:value => 'Add To Cart')
      c.define_tag('product:add_to_cart:quantity') do |tag|
        size = tag.attr['size'] || 2
        class_name = tag.attr['css'] || 'quantity_text_field'
        type = tag.attr['type'] || 'input'
        
        if type == 'select'
          limit  =(tag.attr['limit'] || 10).to_i
          "<select name='shop#{data[:paragraph_id]}[quantity]'>" +
              (1..limit).to_a.collect { |num| "<option value='#{num}'>#{num}</option>" }.join("\n") +
          "</select>"
        else
          "<input class='#{class_name}' type='text' name='shop#{data[:paragraph_id]}[quantity]' value='1' size='#{size}' />"
        end      
      end

      define_image_tag(c,'product:image','product','image_file')
      define_image_tag(c,'product:img','product','image_file')
      

      c.define_tag 'product:price' do |tag|
        price = tag.locals.product.get_price(data[:currency])
        price ? price.localized_price : ''
      end

      c.define_tag 'product:href' do |tag|
        "href='#{data[:detail_page].blank? ? '' : data[:detail_page] + "/" + tag.locals.product.id.to_s }'"
      end

      define_position_tags(c)

      c.define_value_tag 'product:description' do |tag|
        if tag.attr['truncate'] 
          simple_format(truncate(tag.locals.product.description,tag.attr['truncate'].to_i))
        elsif tag.attr['list']
          "<ul>" + tag.locals.product.description.split("\n").map { |txt| "<li>" + txt.strip.to_s + "</li>" }.join("") + "</ul>"
        else
          simple_format(tag.locals.product.description)
        end
      end

      %w(name weight dimensions detailed_description name_2 brand).each do |elem|
        c.define_tag 'product:' + elem do |tag|
          tag.locals.product.send(elem)
        end
      end

      c.define_pagelist_tag 'products:pages' do |tag|
          tag.locals.page_data  
      end
    end

      
    parse_feature(feature,parser_context)
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
      currency = @mod.options[:currency] || 'USD'
      
      if params[:search]
        search = params[:search]
        pages,products = Shop::ShopProduct.run_search(params[:search])
      end
      
      data = { :pages => pages, :products => products, :category => category, :detail_page => detail_page, :items_per_page => items_per_page, :currency => currency, :paragraph_id => paragraph.id, :search => search, :page => params[:page]}
      
      if flash[:shop_product_added]
        data[:product_added] = flash[:shop_product_added]
      end

      feature_output = product_listing_feature(get_feature('shop_product_listing'),data)

      DataCache.put_content("ShopCategory",target_string,display_string,feature_output) unless editor?  || params[:search]
    end
    
    require_css('gallery')

    render_paragraph :text => feature_output
  end

  feature :shop_product_detail, :default_feature => <<-FEATURE
      <cms:product>
        <cms:product_added>
        <div align='center'>
          "<cms:name/>" has been added to your cart
        </div>
        </cms:product_added>
        <div class='product_detail'>
          <cms:img align='left' border='10' size='preview' shadow='1' />
          <h3><cms:name/></h3>
          <cms:no_options>
          <cms:price/>
          </cms:no_options>
          <br/><br/>
          <cms:quantities/>
          <cms:options/>Quantity:<cms:quantity/><cms:add_to_cart>Add To Cart</cms:add_to_cart><br/>
          <br/>
          <cms:description/>
          <br/>
          <cms:detailed_description>
              <hr/>
              <cms:value/>
          </cms:detailed_description>
        </div>
      </cms:product>
      <cms:no_product>Invalid Product</cms:no_product>
  FEATURE

  def product_detail_feature(feature,data)

   parser_context = FeatureContext.new do |c|
      c.define_tag 'no_product' do |tag|
        data[:product] ? nil : tag.expand
      end
      c.define_tag 'product' do |tag|
        tag.locals.product = data[:product]
        if data[:product]
          <<-HTML
            <form action='' method='post'>
               <input type='hidden' name='shop#{data[:paragraph_id]}[action]' value='add_to_cart'/>
               <input type='hidden' name='shop#{data[:paragraph_id]}[product]' value='#{data[:product].id}'/>
               #{tag.expand}
            </form>
          HTML
        else
          nil
        end
        
      end
      
   
     c.define_value_tag 'product:description' do |tag|
        if tag.attr['truncate'] 
          simple_format(truncate(tag.locals.product.description,tag.attr['truncate'].to_i))
        elsif tag.attr['list']
          "<ul>" + tag.locals.product.description.split("\n").map { |txt| "<li>" + txt.strip.to_s + "</li>" }.join("") + "</ul>"
        else
          simple_format(tag.locals.product.description)
        end
      end


      %w(name weight dimensions detailed_description sku internal_sku  name_2 brand).each do |elem|
        c.define_value_tag 'product:' + elem do |tag|
          data[:product].send(elem)
        end
      end

      c.define_tag 'price' do |tag|
        price = tag.locals.product.get_price(data[:currency])
        price ? price.localized_price : ''
      end
      
      c.define_tag 'quantity' do |tag|
        size = tag.attr['size'] || 2
        class_name = tag.attr['css'] || 'quantity_text_field'
        type = tag.attr['type'] || 'input'
        
        if type == 'select'
          limit  =(tag.attr['limit'] || 10).to_i
          "<select name='shop#{data[:paragraph_id]}[quantity]'>" +
              (1..limit).to_a.collect { |num| "<option value='#{num}'>#{num}</option>" }.join("\n") +
          "</select>"
        else
          "<input class='#{class_name}' type='text' name='shop#{data[:paragraph_id]}[quantity]' value='1' size='#{size}' />"
        end
      end

      c.define_tag 'no_options' do |tag|
        cls = data[:product].shop_product_class
        
        if cls
          cls.shop_variations.length > 0 ? nil : tag.expand
        else
          nil
        end
        
      end
      
      c.define_tag 'options' do |tag|
        cls = data[:product].shop_product_class
        
        price = tag.locals.product.get_price(data[:currency],myself)
        price = price ? price.price : 0.0
        
        no_prices = tag.attr['no_prices'] ? true : false
                
        if cls && cls.shop_variations.length > 0
        
          output = ''
          unit_cost = data[:product].get_unit_cost(data[:currency])
          cls.option_variations.each do |variation|
            opts = data[:product].get_variation_options(variation,data[:currency]).collect do |opt|
              if no_prices
                "<option value='#{opt[2]}'>#{h opt[0]}</option>"
              else
                if cls.shop_variations.length == 1
                  opt_price_localized = Shop::ShopProductPrice.localized_amount(opt[1] + unit_cost,data[:currency])
                  "<option value='#{opt[2]}'>#{h opt[0]} - #{opt_price_localized}</option>"
                else
                  opt_price_localized = Shop::ShopProductPrice.localized_amount(opt[1],data[:currency])
                  modifier = opt[1] > 0 ? "+" : "-"
                  "<option value='#{opt[2]}'>#{h opt[0]} - #{modifier}#{opt_price_localized}</option>"
                
                end
              end
            end
            output += <<-EOF
              <select name='shop#{data[:paragraph_id]}[variation][#{variation.id}]'>
                #{opts.join("\n")}
              </select>
              EOF
          end
          output
          
        else
          nil
        end
      end 
  
  
      define_submit_tag(c,'add_to_cart',:default => 'Add To Cart')
  
      c.define_tag 'product_added' do |tag|
        if data[:product_added] 
          tag.locals.product_added = Shop::ShopProduct.find_by_id(data[:product_added])
          tag.expand
        else
          nil
        end
      end
      
      c.define_tag 'list_page' do |tag|
        tag.locals.value = data[:list_page]
        data[:list_page] ? tag.expand : nil
      end
      
      c.define_tag 'list_page:href' do |tag|
        editor? ? "href='#'" : "href='#{data[:list_page]}'"
      end
      

      c.define_tag 'product_added:name' do |tag|
        tag.locals.product_added ? tag.locals.product_added.name : 'Invalid Product'.t
      end

      define_image_tag(c,'product:img','product','image_file')
      
      define_image_tag(c,'product:extra_img','product') do |product,tag|
        index = (tag.attr.delete('number') || 1).to_i - 1
        index = 0 if index < 0
        file  = product.images[index]
        img = file.domain_file if file
      end
      
      c.link_tag('product:file') do |tag|
        index = (tag.attr.delete('number') || 1).to_i - 1
        index = 0 if index < 0
        file  = tag.locals.product.files[index]
        if file
          file.domain_file.url
        else
          nil
        end
      end
      
      c.define_tag 'product:extra_imgs' do |tag|
        output = ''
        tag.locals.product.images.each do |img|
          tag.locals.image = img
          output += tag.expand
        end
        output
      end
      
      define_image_tag(c,'product:extra_imgs:img','image') do |prd_file,tag|
        prd_file.domain_file
      end
      
      
    # Get each of the handler option models
    get_handler_info(:site_feature,:shop_product_detail).each do |handler|
        handler[:class].shop_product_detail_feature(c,data)
    end      
      
   end

      
    parse_feature(feature,parser_context)
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
      product_connection,product_link = page_connection()

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
      currency = @mod.options[:currency] || 'USD'

      data = { :product => product, :currency => currency, :paragraph_id => paragraph.id, :user => myself }
      
      if options[:list_page_id].to_i > 0
        data[:list_page] = SiteNode.get_node_path(options[:list_page_id])
      end

      if flash[:shop_product_added]
        data[:product_added] = flash[:shop_product_added]
      end

      feature_output = product_detail_feature(get_feature('shop_product_detail'),data)

      DataCache.put_content("ShopProduct",target_string,display_string, [  product_id,product_name,feature_output ]) if @caching_active
    end
    
    require_css('gallery')

    render_paragraph :text => feature_output
  end


  feature :display_cart, :default_feature => <<-FEATURE
      <div class='cart'>
      <b>Shopping Cart</b><br/>
      <cms:product_count>You have <cms:value/> <cms:count value='1'>product</cms:count><cms:count not_value='1'>products</cms:count> in your cart<br/></cms:product_count>
      <cms:no_product_count>Your cart is empty<br/></cms:no_product_count>
      <a <cms:href/>>View your cart</a>
      </div>
  FEATURE

  def display_cart_feature(feature,data)

   parser_context = FeatureContext.new do |c|

      define_block_value_tag(c,'product_count') { 
        data[:cart].products_count > 0 ? data[:cart].products_count : nil
      }

      c.define_tag 'product_count:count' do |tag|
        if tag.attr['value']
          value_arr = tag.attr['value'].split(',')
          value_arr.include?(data[:cart].products_count) ? tag.expand : nil
        elsif tag.attr['not_value']
          value_arr = tag.attr['not_value'].split(',')
          value_arr.include?(data[:cart].products_count) ? nil : tag.expand 
        else
          nil
        end
      end
      
      c.define_value_tag 'total' do |tag|
          Shop::ShopProductPrice.localized_amount(data[:cart].total(data[:currency]),data[:currency])
      end
    
      c.define_tag 'href' do |tag|
        "href='#{data[:full_cart_page].blank? ? '#' : data[:full_cart_page]}'"
      end

   end
   parse_feature(feature,parser_context)
  end

  def display_cart
    options = paragraph.data || {}

    cart = get_cart

    full_cart_page =  SiteNode.get_node_path(options[:full_cart_page_id],'#')

      @mod = get_module
    currency = @mod.options[:currency] || 'USD'

    data = { :cart=> get_cart, :full_cart_page => full_cart_page, :currency => currency }

    feature_output = display_cart_feature(get_feature('display_cart'),data)
    

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


  feature :shop_page_category_breadcrumbs, :default_feature => <<-FEATURE   
    <ul class='categories'>
    <cms:categories>
    <cms:category>
      <li class='level_<cms:level/>'>
        <cms:current><cms:title/></cms:current>
        <cms:not_current><cms:link>><cms:title/></cms:link></cms:not_current>
      </li>
      </cms:category>
    </cms:categories>
    </ul>
    <cms:subcategories>
      <cms:subcategory><li>-<cms:link><cms:title/></cms:link></li></cms:subcategory>
    </cms:subcategories>
  FEATURE
  
  def shop_page_category_breadcrumbs_feature(data)
    webiva_feature(:shop_page_category_breadcrumbs) do |c|
      c.loop_tag('category') { |t| data[:categories] }
        c.link_tag('category:') { |t| data[:page_url] + "/" + t.locals.category.id.to_s }
        c.value_tag('category:title') { |t| t.locals.category.name }
        c.value_tag('category:level') { |t| t.locals.index+1 }
        c.value_tag('category:description') { |t| t.locals.category.description }
        c.expansion_tag('category:current') { |t| data[:selected_category] && t.locals.category.id == data[:selected_category].id }
        c.expansion_tag('category:not_current') { |t| data[:selected_category] &&  t.locals.category.id != data[:selected_category].id  }
      c.loop_tag('subcategory') { |t| data[:child_categories] }
        c.link_tag('subcategory:') { |t| data[:page_url] + "/" + t.locals.subcategory.id.to_s }
        c.value_tag('subcategory:title') { |t| t.locals.subcategory.name }
        c.value_tag('subcategory:description') { |t| t.locals.subcategory.description }
        c.expansion_tag('subcategory:current') { |t| t.locals.index == 0 }
        c.expansion_tag('subcategory:not_current') { |t| t.locals.index != 0 }
      c.position_tags
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
    category_list << selected_category  if selected_category
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
