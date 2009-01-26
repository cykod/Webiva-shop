
class Shop::ShopProductOption < DomainModel

  belongs_to :variation_option, :class_name => 'Shop::ShopVariationOption', :foreign_key => 'shop_variation_option_id'

  serialize :prices
end
