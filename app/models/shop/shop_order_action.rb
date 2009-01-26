
class Shop::ShopOrderAction < DomainModel

  belongs_to :end_user
  belongs_to :shop_order, :class_name => 'Shop::ShopOrder'
    

end
