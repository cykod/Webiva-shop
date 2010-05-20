
class Shop::ShopSessionCart < Shop::ShopCartBase

  attr_accessor :user
  attr_reader :currency
  
  # cart_storage and be either and end_user or a array in the session variable
  def initialize(cart_storage,currency,user=nil)
    @cart_storage = cart_storage 
    @user = user || EndUser.new
    @currency = currency
  end

  def clear
     cart_storage = [ ]
  end
  
   attr_accessor :shipping

  def add_product(product,quantity,options={})
    @products = nil
    @cart_storage.each do |item|
      if(item[:cart_item_type] == product.class.to_s &&
         item[:cart_item_id] == product.id &&  
         item[:options] == options)
          item[:quantity] += quantity
          return 
      end
    end
    @cart_storage << { :cart_item_type => product.class.to_s, :cart_item_id => product.id, :quantity => quantity, :options => options }
  end

  def edit_product(product,quantity,options={},quantity_options=nil)
    @products = nil
  
    @cart_storage.each do |item|
      if(item[:cart_item_type] == product.class.to_s &&
         item[:cart_item_id] == product.id &&  
         item[:options] == options)
        if quantity > 0 
          item[:quantity] = quantity
          item[:quantity_options] = quantity_options
          return
        else
          @cart_storage.delete(item)
          return  
        end
      end
    end
  end

  def products_count
    @cart_storage.length
  end
  

  def products(reload = false)
    @products = nil if reload
    
    return @products if @products
    @products = @cart_storage.collect do |itm|
      if itm[:cart_item_type] == "Shop::ShopProduct"
        prd = Shop::ShopProduct.find_by_id(itm[:cart_item_id], :include => :prices)
      else
        prd = itm[:cart_item_type].constantize.find_by_id(itm[:cart_item_id])
      end
      if prd
        cart_product = Shop::ShopCartProduct.new(:end_user => @user, :cart_item => prd, :quantity => itm[:quantity], :options => itm[:options],:quantity_options => itm[:quantity_options]||{}  )
      else
        @cart_storage.delete(itm)
        cart_product = nil
      end
    end.find_all { |itm| !itm.blank? }
  end    
 
  def validate_cart!
    products.each do |prd|
      item = prd.item
      if item
        cart_limit = item.cart_limit(prd.options,self) if item.respond_to?(:cart_limit)
    
        if item.respond_to?(:update_cart_options!)
          save_changes = item.update_cart_options!(prd,self) 
          edit_product(item,prd.quantity,prd.options,prd.quantity_options) if save_changes
        end
        if cart_limit && cart_limit == 0
          edit_product(item,0,prd.options)
        elsif !cart_limit.blank? && prd.quantity > cart_limit
          edit_product(item,cart_limit,prd.options,prd.quantity_options)
        end
      else
        edit_product(item,0,prd.options)
      end
    end
    @products=nil
  end

    
end
