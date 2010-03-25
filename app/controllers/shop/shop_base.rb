
module Shop::ShopBase 

  def get_currencies
     @mod_opts ||= Shop::AdminController.module_options
     [@mod_opts.shop_currency || 'USD' ]
  end

end

