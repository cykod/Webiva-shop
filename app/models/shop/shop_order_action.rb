
class Shop::ShopOrderAction < DomainModel

  belongs_to :end_user
  belongs_to :shop_order, :class_name => 'Shop::ShopOrder'
    
  has_options :order_action, [
            [ 'Capture','captured' ],
            [ 'Refund','refund' ],
            [ 'Void','voided' ],
            [ 'Ship','shipped' ],
            [ 'Note','note' ] ]

end
