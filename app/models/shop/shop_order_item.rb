
class Shop::ShopOrderItem < DomainModel

  serialize :options
  
  belongs_to :order_item, :polymorphic => true
  
  belongs_to :order, :class_name => "Shop::ShopOrder"
  
  def display_unit_price
    Shop::ShopProductPrice.localized_amount(unit_price,currency)    
    
  end
  
  def display_subtotal
    Shop::ShopProductPrice.localized_amount(subtotal,currency)    
  end
  
  def self.purchased_item(user,item)
    self.find(:first,:conditions => { :processed => true, 
                                      :order_item_type => item.class.to_s,  
                                      :order_item_id => item.id,
                                      :end_user_id => user.id })
  end

end
