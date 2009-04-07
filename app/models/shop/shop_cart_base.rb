

class Shop::ShopCartBase 

attr_accessor :shipping

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
    cart_total + self.shipping.to_f
  end
  
  def product_total(product_ids)
    cart_total = 0.0
    products.each do |product|
      if product.cart_item_type == 'Shop::ShopProduct' && product_ids.include?(product.cart_item_id)
        cart_total += product.price(self) * product.quantity
      end
    end
    cart_total + self.shipping.to_f
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
  
  # Return the cart total without any coupons or shipping
  def full_price
    cart_total = 0.0
    products.each do |product|
      if product.cart_item_type != 'Shop::ShopCoupon'
        prc = product.price(self)
        if prc > 0
          cart_total +=  prc * product.quantity
        end
      end
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