
class Shop::ShopUserCart  < Shop::ShopCartBase

  attr_reader :user
  attr_reader :currency
  
  
  def initialize(user,currency)
    @user = user
    @currency = currency
  end

  def add_product(product,quantity,options = {})
     Shop::ShopCartProduct.add_product(self,@user,product,quantity,options)
     @products = nil
  end

  def edit_product(product,quantity,options = {})
     Shop::ShopCartProduct.add_product(self,@user,product,quantity,options,:override => true)
     @products = nil
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
  
 def validate_cart!
    products.each do |prd|
      validate_item!(prd)
    end
    
    @products=nil
  end
  
  def validate_item!(prd)
    item = prd.item
    if item
      cart_limit = item.cart_limit(prd.options,self) if item.respond_to?(:cart_limit)

      if item.respond_to?(:update_cart_options!)
        save_changes = item.update_cart_options!(prd,self) 
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
end
