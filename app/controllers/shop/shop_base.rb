
module Shop::ShopBase 

  def get_currencies
    Shop::ShopProduct.active_currencies
  end

end

