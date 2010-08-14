
class Shop::ShopProductOption < DomainModel

  belongs_to :variation_option, :class_name => 'Shop::ShopVariationOption', :foreign_key => 'shop_variation_option_id'
  
  belongs_to :image, :class_name => 'DomainFile',:foreign_key => 'image_id'

  serialize :prices

  def prices=(val)
    self.write_attribute(:prices,val.to_hash)
  end
  
 def images
    return @images if @images
    
    @images = self.image_list.to_s.split(",").find_all { |elm| !elm.blank? }
    
    @images = DomainFile.find(:all,:conditions => { :id => @images })
  end  
end
