
class Shop::Features::ProfileQuantityOption < Shop::ProductFeature

   def self.shop_product_feature_handler_info
    { 
      :name => 'Profile Quantity Option',
      :callbacks => [ :update_cart ],
      :options_partial => "/shop/features/profile_quantity_option"
    }
   end
   
   def price
   
   end

   def self.options(val)
    ProfileClassOptions.new(val)
   end
   
   class ProfileClassOptions < HashModel
    default_options :member_class_id => [], :option_number => []
    
   end
   
   
   def self.description(opts)
    opts = self.options(opts)
    "Profile Quantity Option"
   end
   
   def update_cart(cart_item)
    return false unless usr = cart_item.end_user
    
    usr_class = usr.user_class_id.to_s
    
    
    self.options.member_class_id.each_with_index do |cls,idx|
      if cls == usr_class
        variation = cart_item.item.quantity_variations[0]
        offset = self.options.option_number[idx].to_i - 1
        current_index = variation.options.map { |elm| elm.id }.index(cart_item.quantity_options[variation.id]) 
        if offset > 0 && variation.options[offset]
          opt = variation.options[offset]
          if cart_item.quantity_options[variation.id] != opt.id && current_index < offset
            cart_item.quantity_options[variation.id] = opt.id          
            return true
          end
        end
      end
    end
   end
   
   def self.site_feature_shop_product_detail_handler_info
    { 
      :name => 'Quantity Detail'
    }
   end
   
   def self.shop_product_detail_feature(c,data)
    c.define_tag 'quantities' do |tag|
    
    
        usr_class =  data[:user].user_class
        
        feature = data[:product].full_features.detect { |feature| feature.shop_feature_handler == "shop/features/profile_quantity_option" }
        tag.locals.current_index = 0
        # Find the feature option and the correct index to use
        if feature && cur_index = feature.feature_options[:member_class_id].index(data[:user].user_class_id.to_s)

          tag.locals.current_index = feature.feature_options[:option_number][cur_index].to_i
        end

        cls = data[:product].shop_product_class
        if cls
          variation = cls.quantity_variations[0]
          if variation
            
            opts = data[:product].get_variation_options(variation,data[:currency])
            if tag.single?
              format = tag.attr['format'] || 'table'
              output = format == 'table' ? "<table class='quantity_cost'><tr>" : ''
              opt_index = 0
              opts.collect do |opt|
                price = Shop::ShopProductPrice.localized_amount(opt[2],data[:currency])
                if format == 'table'
                  output += "<td #{"style='color:red;'" if opt_index == cur_index }>#{opt[0]}<br/>#{opt[1]}<br/>#{price}</td>"
                else
                  output += "<div>#{opt[0]}<br/>#{opt[1]}<br/>#{price}</div>"
                end
                opt_index += 1
              end
              
              output += format == 'table' ? "</tr></table>" : ''
            else
              c.each_local_value(opts,tag,'quantity')
            end
          else
            nil
          end
        else
          nil
        end
        
      end
      c.expansion_tag('quantities:current') { |tg| tg.locals.current_index == tg.locals.index  }
      c.expansion_tag('quantities:below') { |tg| tg.locals.current_index < tg.locals.index  }
      c.expansion_tag('quantities:above') { |tg| tg.locals.current_index > tg.locals.index  }
      
      c.define_value_tag('quantities:name') do |tg| 
        if(tg.attr['names'])
          names = tg.attr['names'].split(",")
          names[tg.locals.index-1]
        else
          tg.locals.quantity[0]
        end
      end      
      
      c.define_value_tag('quantities:amount') { |tg| tg.locals.quantity[1] }
      c.define_value_tag('quantities:min') { |tg| tg.locals.quantity[3] }
      c.define_value_tag('quantities:max') { |tg| tg.locals.quantity[4] }
      
      c.define_value_tag('quantities:cost') { |tg| sprintf("%0.2f",tg.locals.quantity[2]) }
      c.define_value_tag('quantities:price') { |tg| Shop::ShopProductPrice.localized_amount(tg.locals.quantity[2],data[:currency]) }
      
      c.define_position_tags('quantities')
   end
   
end
