
class Shop::ShopCategoryProduct < DomainModel
  
  belongs_to :shop_category, :class_name => 'Shop::ShopCategory',
:foreign_key => 'shop_category_id'
  belongs_to :shop_product, :class_name => 'Shop::ShopProduct', :foreign_key => 'shop_product_id'


end