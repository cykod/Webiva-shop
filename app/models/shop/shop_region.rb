
class Shop::ShopRegion < DomainModel

  validates_presence_of :name
  validates_numericality_of :tax
  
  has_many :countries, :class_name => 'Shop::ShopRegionCountry', :dependent => :delete_all, :order => 'country'
  has_many :subregions, :class_name => "Shop::ShopSubregion", :dependent => :delete_all
  has_options :subregion_type, [ [ 'State', 'state' ], [ 'Province','province' ], ['Region','region' ], ['District','district'], ['Area','area'] ]

  has_many :shipping_categories, :class_name => "Shop::ShopShippingCategory", :dependent => :destroy
  
  def country
    c = self.countries[0]
    c ? c.country : nil
  end 
  
  def self.validate_country_and_state(address)
  
  end
  
end
