
module Shop::CartUtility
  def get_cart
    if myself.id
      cart = Shop::ShopUserCart.new(myself)

      if session[:shopping_cart]
        cart.transfer_session_cart(Shop::ShopSessionCart.new(session[:shopping_cart]))
        session[:shopping_cart] = nil
      end
      cart
    else
      session[:shopping_cart] ||= []
      Shop::ShopSessionCart.new(session[:shopping_cart])
    end
  end
  
end
