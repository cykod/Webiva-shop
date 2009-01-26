
class Shop::ShopCarrier < DomainModel

  validates_presence_of :name, :carrier_processor
  validates_uniqueness_of :name
  
  attr_protected :carrier_processor

  has_many :shipping_categories, :class_name => "Shop::ShopShippingCategory", :dependent => :destroy

  def processor_name
      cls = self.processor
      cls.shop_carrier_processor_handler_info[:name] if cls
  end  

  def processor
    self.carrier_processor.blank? ? nil : self.carrier_processor.classify.constantize 
    
  end


  
end
