
class Shop::ShopOrderItem < DomainModel

  serialize :options
  
  belongs_to :order_item, :polymorphic => true
  
  belongs_to :order, :class_name => "Shop::ShopOrderItem"
  
  def display_unit_price
    Shop::ShopProductPrice.localized_amount(unit_price,currency)    
    
  end
  
  def display_subtotal
    Shop::ShopProductPrice.localized_amount(subtotal,currency)    
  end

end
