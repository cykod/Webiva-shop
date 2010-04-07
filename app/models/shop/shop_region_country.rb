
class Shop::ShopRegionCountry < DomainModel

  belongs_to :region, :class_name => 'Shop::ShopRegion', :foreign_key => :shop_region_id


  def generate_state_info(current_state)
    if(self.region.has_subregions? )
      subregions = self.region.subregions.collect { |rgn| [ rgn.name, rgn.abr.blank? ? rgn.name : rgn.abr ] }
      selected = self.region.subregions.find(:first, :conditions => ['name = ? OR abr = ?',current_state,current_state]) unless current_state.blank?
      selected = selected.abr if selected
      subregion_name = self.region.subregion_type_display
      return  { :selected => selected, :options => subregions, :name => subregion_name }
    else
      return  {:selected => current_state }
    end
  end
  
  def self.locate(country)
    shop_region = self.find_by_country(country,:include => :region)
    if !shop_region
      shop_region = self.find_by_country("Rest of the World",:include => :region)
    end
    shop_region
  end

  def self.all_countries
    self.find_by_country("Rest of the World") 
  end

  def self.country_select_options
     Shop::ShopRegionCountry.find(:all,:order => 'country',
                                 :conditions => [ "country != 'Rest of the World'" ],:group => "country" ).collect { |cnt| [ cnt.country.t,cnt.country ] }.sort { |a,b| a[0] <=> b[0] }

  end

  def calculate_tax(cart,address)
    self.region.calculate_tax(cart,address)
  end

  def self.full_select_options
    countries = [['--Select Country--','']] + Shop::ShopRegionCountry.country_select_options  
    # hack to tell it to show all countries and put some on top
    if Shop::ShopRegionCountry.all_countries 
      countries = { :countries => countries[1..-1].map { |c| c[1] } }
    end 
    countries
  end
  
  
  def shipping_details(cart)
   # TODO: Shipping Categories depend on Currency as well
      shipping  = self.region.shipping_categories.find(:all,:include => :carrier)
      # Find the available Shipping Categories going to that region

      shipping.collect do |cat|
        processor = cat.carrier.processor.new(cat.options)
        { :category => cat, 
          :shipping =>processor.calculate_shipping(cart),
          :processor => processor 
        }
      end
  end
  
  def shipping_options(currency,shipping_info)
     shipping_options = shipping_info.collect do |info|
        [ "#{info[:category].name} - " + Shop::ShopProductPrice.localized_amount(info[:shipping],currency), info[:category].id ]
      end  
  end
end
