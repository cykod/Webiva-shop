
class Shop::ShopSubregion < DomainModel

  validates_presence_of :name
  validates_numericality_of :tax
  validates_uniqueness_of :name
  validates_uniqueness_of :abr, :allow_nil => true

  belongs_to :shop_region, :class_name => "Shop::ShopRegion"
  
end
