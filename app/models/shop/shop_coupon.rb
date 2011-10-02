
class Shop::ShopCoupon < DomainModel

  has_many :shop_coupon_products, :class_name => 'Shop::ShopCouponProduct'
  has_many :shop_products, :through => :shop_coupon_products, :class_name => "Shop::ShopProduct"

  
  has_options :discount_type, [['Amount','amount'],['Percentage','percentage']]
  
  validates_numericality_of :discount_amount, :greater_than => 0, :if => Proc.new { |coupon| coupon.discount_type == 'amount' }
  validates_numericality_of :discount_percentage, :greater_than => 0, :if => Proc.new { |coupon| coupon.discount_type == 'percentage' }  
  
  validates_presence_of :internal_name,:cart_name,:code
  
  validates_uniqueness_of :code
  
  validates_datetime :expires_at, :allow_nil => true
  
  def shop_product_ids=(val)
    @shop_product_ids_cache = val
  end
  
  def after_save
    if @shop_product_ids_cache
      self.shop_coupon_products = []
      @shop_product_ids_cache.each do |product_id|
        self.shop_coupon_products.create(:shop_product_id => product_id)
      end
    end
  end
  
  def discount_display
    if self.discount_type == 'amount'
      sprintf("-%0.2f",self.discount_amount.to_f)
    else
      sprintf("-%0.2f%%",self.discount_percentage.to_f)
    end
  end
  
  def self.search_coupon(code,cart)
    coupon = self.find_by_code(code)
    if coupon 
      if coupon.cart_limit({},cart) > 0
        return coupon
      end
    else
      cart.add_message("'%s' is not a valid coupon." / CGI::escapeHTML(code))
    end
    nil
  end
  
  def self.automatic_coupons(cart)
    coupons = self.find(:all,:conditions => { :active => 1, :automatic => true })
    coupons.select do |coupon|
      coupon.cart_limit({},cart) > 0    
    end
  end

  def coupon?
    true
  end
  
  def name
    self.cart_name
  end
  
  def cart_details(options,cart)
    self.cart_description
  end

  def cart_shippable?
    false
  end
  
  def cart_sku
    "COUPON#" + self.id.to_s
  end

  
  def cart_price(options,cart)
    if self.discount_type == 'amount'
      -self.discount_amount
    else
      if self.all_products?
        -(cart.full_price * self.discount_percentage / 100).round(2)
      else
        -(cart.product_total(self.shop_product_ids) * self.discount_percentage / 100).round(2)
      end
    end
  end

  def activate!
    self.update_attributes(:active => true) if !self.active
  end
  

  def deactivate!
    self.update_attributes(:active => false) if self.active
  end
  

  def cart_limit(options,cart)
    # Coupon must be active and not expired
    unless self.active? && (!self.expires_at || self.expires_at > Time.now)
      cart.add_message("'%s' is no longer a valid code." / self.code)
      return 0
    end

    # None of the affected items are in the cart
    if !self.all_products? && cart.item_quantity("Shop::ShopProduct",self.shop_product_ids) == 0
      cart.add_message("'%s' does not apply any items in your cart." / self.code)
      return 0 
    end
    
    # We've already used this coupon
    if self.one_time? && Shop::ShopOrderItem.purchased_item(cart.user,self)
      cart.add_message("'%s' has been used already." / self.code)
      return 0
    end
    
    # Check for tags
    if !self.tag.blank? && !cart.user.tag_names.include?(self.tag)
      cart.add_message("'%s' is not a valid code for your account." / self.code)
      return 0
    end
    
    # Check if this is only for users first order
    if self.first_order? && !Shop::ShopOrder.first_order?(cart.user)
      cart.add_message("'%s' can only be used on your first order." / self.code)
      return 0
    end
    
    # Check if this is only for users first order
    if self.exclusive? && !cart.item_exclusive("Shop::ShopCoupon",self.id)
      cart.add_message("'%s' cannot be combined with other coupons." / self.code)
      return 0
    end
    
    
    return 0 if cart.real_items == 0
    
    return 1
  end
  
  
  
  def cart_post_processing(user,order_item,session)
  end     
end
