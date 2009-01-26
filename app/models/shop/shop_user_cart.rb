
class Shop::ShopUserCart 

  def initialize(user)
    @user = user
  end

  def add_product(product,quantity,options)
     Shop::ShopCartProduct.add_product(@user,product,quantity,options)
  end

  def edit_product(product,quantity,options)
     Shop::ShopCartProduct.add_product(@user,product,quantity,options,:override => true)
  end

  def transfer_session_cart(session_cart)
    session_cart.products.each do |cart_prd|
      add_product(cart_prd.cart_item,cart_prd.quantity,cart_prd.options)
    end
  end

  def products_count
    return @products_count if @products_count
    @products_count = Shop::ShopCartProduct.count(:all,:conditions => [ 'end_user_id=?',@user.id ] )
  end
  
  def products
    return @products if @products
    @products = Shop::ShopCartProduct.find(:all,:conditions => [ 'end_user_id=?',@user.id ],:order => 'shop_cart_products.id',:include => [ { :shop_product => [ :prices, :shop_product_class ] } ])
  end
  
  def clear
    products.each do |prd|
      prd.destroy
    end
  end
  
  attr_accessor :shipping
  
  def total(currency)
    total = 0.0
    products.each do |product|
      total += product.price(currency) * product.quantity
    end
    total + self.shipping.to_f
  end
  
  def validate_cart!
    products.each do |prd|
      validate_item!(prd)
    end
    
    @products=nil
  end
  
  def validate_item!(prd)
    item = prd.item
    if item
      cart_limit = item.cart_limit(prd.options,@user) if item.respond_to?(:cart_limit)

      if item.respond_to?(:update_cart_options!)
        save_changes = item.update_cart_options!(prd) 
      end
      if cart_limit && cart_limit == 0
        prd.destroy
      elsif cart_limit && prd.quantity > cart_limit 
        prd.quantity = cart_limit
        save_changes = true
      end
    else
      prd.destroy
    end
    prd.save if save_changes
  end
  
  def shippable? 
    products.each do |prd|
      return true if prd.item.cart_shippable?
    end
    return false
  end
end
