

class Shop::ShopCartBase 

attr_accessor :shipping, :tax

  def add_message(msg)
    @messages ||= []
    @messages << msg
  end
  
  def messages
    @messages || []
  end
  
  def total
    cart_total = 0.0
    products.each do |product|
      cart_total += product.price(self) * product.quantity
    end
    cart_total + self.shipping.to_f + self.tax.to_f
  end
  
  def shippable_total
    cart_total = 0.0
    products.each do |product|
      if product.item.cart_shippable?
        cart_total += product.price(self) * product.quantity
      end
    end
    cart_total
  end
  
  def product_total(product_ids)
    cart_total = 0.0
    products.each do |product|
      if product.cart_item_type == 'Shop::ShopProduct' && product_ids.include?(product.cart_item_id)
        cart_total += product.price(self) * product.quantity
      end
    end
    cart_total
  end

  def taxable_total
    cart_total = 0.0
    products.each do |product|
      if product.item.respond_to?(:cart_taxable?)
        cart_total += product.price(self) * product.quantity if product.item.cart_taxable?
      end
    end
    cart_total
  end
  
  def item_quantity(item_type,product_ids)
    product_ids = [ products_id] unless product_ids.is_a?(Array)
   
    cnt = 0 
    products.each do |product|
      if product.cart_item_type == item_type && product_ids.include?(product.cart_item_id)
        cnt += product.quantity
      end
    end
    cnt
  end
  
  def item_exclusive(item_type,product_id)
   
    cnt = 0 
    products.each do |product|
      if product.cart_item_type == item_type && product_id != product.cart_item_id
        cnt += product.quantity
      end
    end
    cnt > 0 ? false : true
  end
  
  
  # Return the cart total without any coupons or shipping
  def full_price
    cart_total = 0.0
    products.each do |product|
      if ! product.coupon?
        prc = product.price(self)
        if prc > 0
          cart_total +=  prc * product.quantity
        end
      end
    end
    cart_total
  end
  
  def real_items
    cart_total = 0
    products.each do |product|
      cart_total += 1 unless product.coupon?
    end
    cart_total
  end
  
 
  
  def shippable? 
    products.each do |prd|
      return true if prd.item.cart_shippable?
    end
    return false
  end


end
