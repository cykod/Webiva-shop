
class Shop::ShopVariationOption < DomainModel

  belongs_to :shop_variation

  serialize :translations
  serialize :prices
  
  has_many :product_options, :class_name => 'Shop::ShopProductOption'


end
