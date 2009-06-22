
class Shop::Features::AddUserTag < Shop::ProductFeature

   def self.shop_product_feature_handler_info
    { 
      :name => 'Add a user tag',
      :callbacks => [ :purchase ],
      :options_partial => "/shop/features/add_user_tag"
    }
   end
   
   def purchase(user,order_item,session)
      # Add the necessary amount of credits
      user.tag_names_add(options.add_tags) unless options.add_tags.blank?
   end

   def self.options(val)
    CreditPackOptions.new(val)
   end
   
   class CreditPackOptions < HashModel
    default_options :add_tags => ''
   end
   
   
   def self.description(opts)
    opts = self.options(opts)
    sprintf("Add Tags (%s)",opts.add_tags.to_s);
   end
   
end
