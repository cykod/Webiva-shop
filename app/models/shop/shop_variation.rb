
class Shop::ShopVariation < DomainModel

  belongs_to :shop_class

  validates_presence_of :name
  
  has_many :options,:class_name => "Shop::ShopVariationOption", :dependent => :destroy, :order => 'option_index'

  has_options :variation_type, [ [ "Product Option (Color,Size,etc...)","option"],["Quantity Option","quantity"]]
  
end
