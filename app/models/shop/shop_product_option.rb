
class Shop::ShopProductOption < DomainModel

  belongs_to :variation_option, :class_name => 'Shop::ShopVariationOption', :foreign_key => 'shop_variation_option_id'
  
  belongs_to :image, :class_name => 'DomainFile',:foreign_key => 'image_id'

  serialize :prices
end
