
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
    self.find_by_country(country,:include => :region)
  end
  
  
  def shipping_details(cart)
   # TODO: Shipping Categories depend on Currency as well
      shipping  = self.region.shipping_categories.find(:all,:include => :carrier)
      # Find the available Shipping Categories going to that region

      shipping.collect do |cat|
        processor = cat.carrier.processor.new(cat.options)
        [ cat, processor.calculate_shipping(cart.products) ]
      end
  end
  
  def shipping_options(currency,shipping_info)
     shipping_options = shipping_info.collect do |info|
        [ "#{info[0].name} - " + Shop::ShopProductPrice.localized_amount(info[1],currency), info[0].id ]
      end  
  end
end
