
class Shop::PageFeature < ParagraphFeature

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
  
  def shop_product_listing_feature(feature,data)
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

  def shop_product_detail_feature(feature,data)

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

      c.value_tag('product_count') { |t| data[:cart].products_count > 0 ? data[:cart].products_count : nil } 

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
          Shop::ShopProductPrice.localized_amount(data[:cart].total,data[:currency])
      end
    
      c.define_tag 'href' do |tag|
        "href='#{data[:full_cart_page].blank? ? '#' : data[:full_cart_page]}'"
      end

   end
   parse_feature(feature,parser_context)
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
     

end
