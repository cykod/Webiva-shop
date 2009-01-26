
module Shop::ShopBase 

  def get_currencies
     [@mod.options[:shop_currency] || 'USD' ]
  end

end

