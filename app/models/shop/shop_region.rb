
class Shop::ShopRegion < DomainModel

  validates_presence_of :name
  validates_numericality_of :tax
  validate :region_countries_logic
  
  has_many :countries, :class_name => 'Shop::ShopRegionCountry', :dependent => :delete_all, :order => 'country'
  has_many :subregions, :class_name => "Shop::ShopSubregion", :dependent => :delete_all, :order => 'shop_subregions.name'
  has_options :subregion_type, [ [ 'State', 'state' ], [ 'Province','province' ], ['Region','region' ], ['District','district'], ['Area','area'] ]

  has_many :shipping_categories, :class_name => "Shop::ShopShippingCategory", :dependent => :destroy
  
  after_create :add_states
  has_options :tax_calc, [
                          ['on Subtotal','subtotal'],
                          ['on Total (inc. Shipping)','total']]

  def region_countries_logic
    Shop::ShopRegionCountry.find(:all,:conditions => [ "country IN(?) AND shop_region_id != ?",self.countries.map(&:country),self.id || 0]).each do |existing_country|
          self.errors.add(:countries,"can only be in one region: please remove " + existing_country.country)
          self.errors.add(:country,"can only be in one region: please remove " + existing_country.country)
        end

  end


  def calculate_tax(cart,address)
    self.tax_handler.calculate_tax(cart,address)
  end

  # for future expansion of tax handlers
  def tax_handler
    if !self.tax_processor.blank?
      @tax_handler ||= self.tax_processor.constantize.new(self)
    else
      @tax_handler ||= Shop::StandardTaxHandler.new(self)
    end
  end


  def country
    c = self.countries[0]
    c ? c.country : nil
  end 
  
  def self.validate_country_and_state(address)
  
  end
  
  def add_states
    if self.has_subregions? && self.countries[0]
      case  self.countries[0].country
      when 'United States'
        self.add_united_states_subregions!
      end 
    end
  end

  def add_united_states_subregions!
    Content::CoreField::UsStateField.states_options.each do |st|
      sr = self.subregions.create(:abr => st[1],:name => st[0])
    end

  end
end
