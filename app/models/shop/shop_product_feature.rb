
class Shop::ShopProductFeature < DomainModel

  validates_presence_of :shop_feature_handler
  attr_protected :shop_feature_handler
  
  serialize :feature_options
  
  belongs_to :shop_product, :class_name => 'Shop::ShopProduct',:foreign_key => 'shop_product_id'
  
  def feature
    return @feature_cls if @feature_cls
    @feature_cls =   self.shop_feature_handler.camelcase.constantize
  end
  
  def name
    self.feature.shop_product_feature_handler_info[:name]
  end
  
  def description
    if self.feature.respond_to?(:description)
      self.feature.description(self.feature_options)
    else
      name
    end
  end
  
  def options
    return @options_object if @options_object
    @options_object = self.feature.options(self.feature_options)
  end
  
  def options_partial
    self.feature.options_partial
  end
  
  def update_callbacks
    cbs = (self.feature.shop_product_feature_handler_info[:callbacks] || []).clone
    
    # Update the callbacks indexers
    %w(price purchase stock shipping rendering update_cart).each do |cb|
      self.send("#{cb}_callback=",cbs.include?(cb.to_sym) ? true : false)
    end
  end
  
  def feature_instance
    self.feature.new(self.shop_product,self)
  end
  
  
  def before_save
    update_callbacks
  end
end
