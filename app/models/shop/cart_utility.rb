
module Shop::CartUtility


 def get_module
    return @mod if @mod
    @mod =  Shop::AdminController.module_options
  end  

  def get_cart
    get_module
    if myself.id && !@shop_user_only
      cart = Shop::ShopUserCart.new(myself,@mod.currency)

      if session[:shopping_cart]
        cart.transfer_session_cart(Shop::ShopSessionCart.new(session[:shopping_cart],@mod.currency))
        session[:shopping_cart] = nil
      end
      cart
    else
      session[:shopping_cart] ||= []
      Shop::ShopSessionCart.new(session[:shopping_cart],@mod.currency)
    end
  end
  
end
