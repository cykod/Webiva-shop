
class Shop::ShopSubregion < DomainModel

  validates_presence_of :name
  validates_numericality_of :tax, :allow_blank => true
  validates_uniqueness_of :name, :scope => :shop_region_id 
  validates_uniqueness_of :abr

  belongs_to :shop_region, :class_name => "Shop::ShopRegion"

  has_options :tax_calc, [['Inherit from Region','inherit'],
                          ['on Subtotal','subtotal'],
                          ['on Total (inc. Shipping)','total']]
  
end
