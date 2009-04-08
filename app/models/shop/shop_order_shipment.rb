

class Shop::ShopOrderShipment < DomainModel

  attr_accessor :notify_customer

  belongs_to :shop_order
  
  has_many :order_items, :class_name => 'Shop::ShopOrderItem'
  
  belongs_to :shop_carrier, :class_name => 'Shop::ShopCarrier'

end
