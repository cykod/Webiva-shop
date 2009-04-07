
class Shop::ShopProductPrice < DomainModel

  belongs_to :shop_product

  has_options :currency, [  ['US Dollar ($)', 'USD' ], ['Euro (EU)', 'EUR' ], ['Swiss Franc (CHF)','CHF'] ]

  cattr_reader :currency_display
  @@currency_display = { 'USD' => [ '$','' ], 'EUR' => [ 'EU ',' EUR' ], 'CHF' => ['CHF ',''] }

  def localized_price(quantity=1)
    Shop::ShopProductPrice.localized_amount(self.price.to_f * quantity,self.currency)
  end


  def self.localized_amount(amount,currency)
    amt = (amount.to_f * 100).to_f
    if amt < 0
      amt = -amt
      neg = '-'
    else
      neg =''
    end
    cur = Currency.new(amt)
    cur_display = @@currency_display[currency] || {}
    neg + cur_display[0].to_s + cur.amount + cur_display[1].to_s
  end
end
