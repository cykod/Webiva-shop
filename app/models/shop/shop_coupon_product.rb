
class Shop::ShopCouponProduct < DomainModel

  belongs_to :shop_coupon, :class_name => 'Shop::ShopCoupon'
  belongs_to :shop_product,:class_name => 'Shop::ShopProduct'

end
