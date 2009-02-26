
class Shop::Features::ProfilePriceAdjustment < Shop::ProductFeature

   def self.shop_product_feature_handler_info
    { 
      :name => 'Profile Price Adjustment',
      :callbacks => [ :price ],
      :options_partial => "/shop/features/profile_price_adjustment"
    }
   end
   
   def self.shop_site_feature_handler_info
    { 
      :name => 'Site Feature Adjustments',
      :callback => 'grid_feature'
    }
   end  
   
   
   def self.grid_feature(c)
    
    
   end
   
   
   def price(currency,price,user)
    
      if user && @options.member_classes.include?(user.user_class_id.to_s)
        if @options.price_adjustments[currency]
          price + @options.price_adjustments[currency]
        else
          price
        end      
      else
        price
      end
   end

   def self.options(val)
    PriceAdjustmentOptions.new(val)
   end
   
   class PriceAdjustmentOptions < HashModel
    default_options :member_classes => [], :price_adjustments => {}
    
    validates_presence_of :member_classes
    
    def validate
      vals = {}
      self.price_adjustments.each do |cur,price|
        vals[cur] = price.to_f  
      end      
      self.price_adjustments = vals
    end
  end
   
   
   def self.description(opts)
    opts = self.options(opts)
    sprintf("Price Adjustment");
   end
   
end
