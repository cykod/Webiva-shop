
class Shop::PageFeature < ParagraphFeature

 feature :shop_product_listing, :default_feature => <<-FEATURE
    <cms:search><em>Searching for '<cms:value/>'</em> </cms:search>
    <cms:category><h2><cms:value/></h2></cms:category>
    <cms:featured_products>
     <h1>Featured Products</h1>
     <ul class='products featured_products'>
       <cms:product>
       <li><cms:img border='1' size='preview' />
           <span class='product_name'><cms:name/></span> &nbsp; 
           <span class='produce_price'><cms:price/></span>
           <p class='product_description'>
              <cms:description/>
           </p>
           <span class='product_buttons'><cms:add_to_cart><cms:quantity/><cms:button/></cms:add_to_cart></span>
           <cms:link>Details &raquo;</cms:link>
       </li>
      </cms:product>
    </ul>
    <hr/>
    </cms:featured_products>
    <cms:products>
    <cms:product>
       <li><cms:img border='1' size='preview' />
           <span class='product_name'><cms:name/></span> &nbsp; 
           <span class='produce_price'><cms:price/></span>
           <span class='product_buttons'><cms:add_to_cart/></span>
           <cms:link>Details &raquo;</cms:link>
       </li>
    </cms:product>
    <div class='product_pages'><cms:pages/></div>
    </cms:products>
  FEATURE
  
  def shop_product_listing_feature(data)
    webiva_feature('shop_product_listing') do |c|
   
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
      
      c.define_value_tag('count') { |tag|  data[:category].product_count(data[:options].shop_shop_id)  }
      
      c.define_tag 'products' do |tag|
        if data[:products]
          tag.locals.page_data = data[:pages]
          tag.locals.products = data[:products]
          tag.locals.search = true
        else
          tag.locals.search = false
          tag.locals.page_data,products = data[:category].paginate_products(data[:options].shop_shop_id,
                                                                           :all, 
                                                                           :per_page => data[:items_per_page], 
                                                                           :page => data[:page])
          tag.locals.products = products
        end
        
        (data[:products] || data[:category].parent_id.to_i == 0 || data[:category].shop_category_products.size > 0) ? tag.expand : nil
      end

      c.define_tag 'no_featured_products' do |tag|
        data[:category].featured_shop_category_products.size ==  0 ? nil : tag.expand
      end
      c.define_tag 'featured_products' do |tag|
        if data[:products] 
          nil
        else
          tag.locals.products = data[:category].find_products(data[:options].shop_shop_id,:featured).collect {|cp| cp.shop_product }
          data[:category].featured_shop_category_products.size > 0 ? tag.expand : nil
        end
      end
      

      c.define_tag 'no_unfeatured_products' do |tag|
        data[:category].unfeatured_shop_category_products.size ==  0 ? nil : tag.expand
      end
      c.define_tag 'unfeatured_products' do |tag|
        tag.locals.products = data[:category].find_products(data[:options].shop_shop_id,:unfeatured).collect {|cp| cp.shop_product }
        data[:category].unfeatured_shop_category_products.size > 0 ? tag.expand : nil
      end


      c.define_tag 'product' do |tag|
        c.each_local_value(tag.locals.products,tag,'product')
      end
      
      c.define_tag 'product:add_to_cart' do |tag|
        if tag.single?
          button = tag.attr['button'] || 'Add to Cart'
          <<-HTML
            <form action="" method="post"><CMS:AUTHENTICITY_TOKEN/>
               <input type='hidden' name='shop#{data[:paragraph_id]}[action]' value='add_to_cart'/>
               <input type='hidden' name='shop#{data[:paragraph_id]}[product]' value='#{tag.locals.product.id}'/>
               <input type='submit' name='go' value='#{vh button}' />
            </form>
          HTML
        else
          <<-HTML
            <form action="" method="post"><CMS:AUTHENTICITY_TOKEN/>
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

      c.image_tag('product:image') { |t| t.locals.product.image_file } 
      c.image_tag('product:img') { |t| t.locals.product.image_file } 
      
      c.image_tag('product:extra_img') do |t|
        index = (t.attr.delete('number') || 1).to_i - 1
        index = 0 if index < 0
        file  = t.locals.product.images[index]
        img = file.domain_file if file
      end      
      

      c.define_tag 'product:price' do |tag|
        price = tag.locals.product.get_price(data[:currency])
        price ? price.localized_price : ''
      end

      c.link_tag 'product:' do |tag|
         if data[:options].include_category
           if !data[:category] || data[:category].parent_id == 0 || data[:options].deepest_category
             deepest_cat = tag.locals.product.deepest_category 
            "#{data[:detail_page]}/#{deepest_cat ? deepest_cat.url : '-'}/#{tag.locals.product.url}#{data[:search_url]}"
           else
            "#{data[:detail_page]}/#{data[:category].url}/#{tag.locals.product.url}#{data[:search_url]}"
           end
         else
            "#{data[:detail_page]}/#{tag.locals.product.url.to_s}#{data[:search_url]}"
         end
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

      %w(name weight dimensions detailed_description name_2 brand sku internal_sku).each do |elem|
        c.define_tag 'product:' + elem do |tag|
          tag.locals.product.send(elem)
        end
      end

      c.define_pagelist_tag 'products:pages' do |tag|
          tag.locals.page_data  
      end
   end
  end
   
   feature :shop_product_detail, :default_feature => <<-FEATURE
      <cms:product>
        <cms:product_added>
        <div align='center'>
          "<cms:name/>" has been added to your cart
        </div>
        </cms:product_added>
        
        <div class='product_detail'>
          <cms:img align='left' border='10' size='small' shadow='1' />
          <cms:category><h4><cms:list_page_link><cms:value/></cms:list_page_link></h4></cms:category>
          <h1><cms:name/></h1>
          <cms:show_price> <cms:price/> </cms:show_price>
          <cms:options/>Quantity:<cms:quantity/><cms:add_to_cart>Add To Cart</cms:add_to_cart>
          <cms:description/>
          <cms:detailed_description>
              <hr/>
              <cms:value/>
          </cms:detailed_description>
        </div>
      </cms:product>
      <cms:no_product>Invalid Product</cms:no_product>
  FEATURE

  def shop_product_detail_feature(data)
    webiva_feature('shop_product_detail',data) do |c|
      c.define_tag 'no_product' do |tag|
        data[:product] ? nil : tag.expand
      end
      c.define_tag 'product' do |tag|
        tag.locals.product = data[:product]
        if data[:product]
          <<-HTML
            <form action="" method="post"><CMS:AUTHENTICITY_TOKEN/>
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


      %w(name weight dimensions detailed_description sku internal_sku  name_2 brand unit_quantity).each do |elem|
        c.define_value_tag 'product:' + elem do |tag|
          data[:product].send(elem)
        end
      end
      
      c.value_tag('product:product_id') { |t| data[:product].id }

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
          tag.expand 
        end
        
      end

      c.define_tag 'show_price' do |tag|
        cls = data[:product].shop_product_class
        
        if cls
          cls.shop_variations.length == 1 ? nil : tag.expand
        else
          tag.expand 
        end
      end
      
      c.define_tag 'options' do |tag|
        cls = data[:product].shop_product_class
        
        price = tag.locals.product.get_price(data[:currency],myself)
        price = price ? price.price : 0.0
        
        no_prices = tag.attr['no_prices'] ? true : false
        
        opt_idx = tag.attr['option']
                
        if cls && cls.shop_variations.length > 0
        
          output = ''
          unit_cost = data[:product].get_unit_cost(data[:currency])
          cls.option_variations.each_with_index do |variation,idx|
            if !opt_idx || (opt_idx.to_i == (idx+1))
              opts = data[:product].get_variation_options(variation,data[:currency]).collect do |opt|
                if opt[3] # In stock?
                  if no_prices
                    "<option value='#{opt[2]}'>#{h opt[0]}</option>"
                  else
                    if cls.shop_variations.length == 1
                      opt_price_localized = Shop::ShopProductPrice.localized_amount(opt[1] + unit_cost,data[:currency])
                      "<option value='#{opt[2]}'>#{h opt[0]}   #{opt_price_localized}</option>"
                    else
                      opt_price_localized = Shop::ShopProductPrice.localized_amount(opt[1],data[:currency])
                      modifier = opt[1] > 0 ? "+" : ""
                      if opt[1] == 0
                        "<option value='#{opt[2]}'>#{h opt[0]}</option>"
                      else
                        "<option value='#{opt[2]}'>#{h opt[0]}   #{modifier}#{opt_price_localized}</option>"
                      end
                    end
                  end
                else 
                  nil
                end
              end.compact
              output += <<-EOF
                <select name='shop#{data[:paragraph_id]}[variation][#{variation.id}]'>
                  #{opts.join("\n")}
                </select>
              EOF
            end
          end
          output
          
        else
          nil
        end
      end 
      
      c.loop_tag('option_detail') do |t| 
        cls = data[:product].shop_product_class
        if cls && cls.shop_variations.length > 0
          opt_idx = (t.attr['option']||1).to_i - 1
          opt_idx = 0 if opt_idx < 0
          variation = cls.option_variations[opt_idx]
          opts = data[:product].get_variation_details(variation)
        else
          nil
        end
      end
          
      c.image_tag('option_detail:img') { |t| t.locals.option_detail[:opt].image }
      
      c.image_tag('option_detail:extra_img') do |t|
        idx = (t.attr.delete('number') || 1).to_i - 1
        idx = 0 if idx < 0
        t.locals.option_detail[:opt].images[idx]      
      end
      
      c.value_tag('option_detail:name') { |t| t.locals.option_detail[:var].name }
      
      c.submit_tag('add_to_cart',:default => 'Add To Cart')
  
      c.define_tag 'product_added' do |tag|
        if data[:product_added] 
          tag.locals.product_added = Shop::ShopProduct.find_by_id(data[:product_added])
          tag.expand
        else
          nil
        end
      end

      c.value_tag('category') { |t| data[:category] ? data[:category].name : nil }
      
      c.define_link_tag 'list_page' do |tag|:w
        data[:list_page]
      end


      
      c.define_tag 'product_added:name' do |tag|
        tag.locals.product_added ? tag.locals.product_added.name : 'Invalid Product'.t
      end

      c.image_tag('product:img') { |t| t.locals.product.image_file }
      
      c.image_tag('product:extra_img') do |t|
        index = (t.attr.delete('number') || 1).to_i - 1
        index = 0 if index < 0
        file  = t.locals.product.images[index]
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
  #  get_handler_info(:site_feature,:shop_product_detail).each do |handler|
  #      handler[:class].shop_product_detail_feature(c,data)
  #  end      
      
   end
  end

 feature :shop_display_cart, :default_feature => <<-FEATURE
      <div class='cart'>
      <b>Shopping Cart</b><br/>
      <cms:product_count>You have <cms:value/> <cms:count value='1'>product</cms:count><cms:count not_value='1'>products</cms:count> in your cart<br/></cms:product_count>
      <cms:no_product_count>Your cart is empty<br/></cms:no_product_count>
      <cms:cart_link>View your cart</cms:cart_link>
      </div>
  FEATURE

  def shop_display_cart_feature(data)
    webiva_feature('shop_display_cart') do |c|

      c.value_tag('product_count') { |t| data[:cart].products_count > 0 ? data[:cart].products_count : nil } 

      c.define_tag 'product_count:count' do |tag|
        if tag.attr['value']
          value_arr = tag.attr['value'].split(',')
          value_arr.include?(data[:cart].products_count.to_s) ? tag.expand : nil
        elsif tag.attr['not_value']
          value_arr = tag.attr['not_value'].split(',')
          value_arr.include?(data[:cart].products_count.to_s) ? nil : tag.expand 
        else
          nil
        end
      end
      
      c.define_value_tag 'total' do |tag|
          Shop::ShopProductPrice.localized_amount(data[:cart].total,data[:currency])
      end
    
      c.define_link_tag 'cart' do |tag|
        data[:full_cart_page]
      end


      c.define_user_tags('user') { |t| data[:user] }
   end
  end
  

  feature :shop_page_category_breadcrumbs, :default_feature => <<-FEATURE   
    <ul class='shop_categories'>
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
      <ul class='shop_subcategories'>
      <cms:subcategory><li>-<cms:link><cms:title/></cms:link></li></cms:subcategory>
      </ul>
    </cms:subcategories>
  FEATURE
  
  def shop_page_category_breadcrumbs_feature(data)
    webiva_feature(:shop_page_category_breadcrumbs) do |c|
      c.loop_tag('category') { |t| data[:categories] }
        c.link_tag('category:') { |t| data[:page_url] + "/" + t.locals.category.url.to_s }
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

end
