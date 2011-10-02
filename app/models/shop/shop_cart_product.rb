
class Shop::ShopCartProduct < DomainModel

  belongs_to :end_user

  serialize :options
  serialize :quantity_options
  
  belongs_to :shop_product, :include => :prices, :class_name => 'Shop::ShopProduct', :foreign_key => 'cart_item_id'
  
  
  belongs_to :cart_item, :polymorphic => true

  def self.add_product(cart,end_user,product,quantity,options=nil,add_options = {})
  
    Shop::ShopCartProduct.transaction do 
      if options
        cart_product = Shop::ShopCartProduct.find(:first,:conditions => ['end_user_id = ? AND cart_item_type=? AND cart_item_id = ? AND options = ?',end_user.id,product.class.to_s,product.id,YAML::dump(options)])
      else
        cart_product = Shop::ShopCartProduct.find(:first,:conditions => ['end_user_id = ? AND cart_item_type = ? AND cart_item_id = ? AND options IS NULL',end_user.id,product.class.to_s,product.id])
      end
      if cart_product
        if(add_options[:override])
          if(quantity > 0)
            cart_product.update_attribute(:quantity,quantity)
          else
            cart_product.destroy
          end
        else
          quantity = cart_product.quantity + quantity
          cart_product.update_attribute(:quantity,quantity)
        end
      elsif quantity > 0
        cart_product = Shop::ShopCartProduct.create(:end_user_id=>end_user.id,
                    :cart_item => product,
                    :quantity => quantity,
                    :options => options)
      end
    end
  end
  
  def quantity_hash
    [ self.item_hash, self.options_hash]  
  end
  
    def item_hash
      Digest::SHA1.hexdigest(YAML.dump(self.cart_item_type.to_s + self.cart_item_id.to_s))
    end
    
    def options_hash
      Digest::SHA1.hexdigest(YAML.dump(self.options || {})) 
    end

  def item
    if self.cart_item_type == 'Shop::ShopProduct'
      self.shop_product
    else
      self.cart_item
    end
  end
  
  def name
    self.item.name
  end
  
  def coupon?
    self.item ? self.item.respond_to?(:coupon?) && self.item.coupon? : false
  end
  
  def price(cart)
    self.item ? self.item.cart_price(self.full_options,cart) : 0.0
  end
  
  def subtotal(cart)
    self.price(cart) * self.quantity
  end
  
  def details(cart)
    self.item.cart_details(self.full_options,cart)
  end
  
  def sku
    self.item.cart_sku
  end

  protected 
  
  # Need to merge the quantity options with the regular options  
  def full_options
    opts = (self.options||{}).clone
    opts[:variations] = (opts[:variations]||{}).clone
    opts[:variations].merge!(self.quantity_options||{})
    opts
  end
    
end
