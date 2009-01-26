
class Shop::ShopShippingCategory < DomainModel

  validates_presence_of :name
  validates_uniqueness_of :name
  validates_presence_of :shop_region_id
  validates_presence_of :shop_carrier_id
  
  serialize :options
  
  belongs_to :carrier, :class_name => "Shop::ShopCarrier", :foreign_key => :shop_carrier_id
  belongs_to :region, :class_name => "Shop::ShopRegion", :foreign_key => :shop_region_id
  
  def before_create
   self.active = true
  end
end
