

class Shop::ProductFeature 


  def initialize(prd,shop_product_feature)
    @product = prd
    @feature = shop_product_feature
    @options = shop_product_feature.options
  end
  
  attr_reader :product,:feature,:options, :redirect_location
  
  def self.options_partial
    self.shop_product_feature_handler_info[:options_partial]
  end
  
  def redirect_to(loc)
    @redirect_location = loc
  end

end
