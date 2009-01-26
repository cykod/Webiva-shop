
class Shop::ShopSessionCart 

  attr_accessor :user
  # cart_storage and be either and end_user or a array in the session variable
  def initialize(cart_storage,user=nil)
    @cart_storage = cart_storage 
    @user = user || EndUser.new
  end
  
   attr_accessor :shipping

  def add_product(product,quantity,options=nil)
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

  def edit_product(product,quantity,options=nil,quantity_options=nil)
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
    
  def total(currency)
    total = 0.0
    products.each do |product|
      total += product.price(currency) * product.quantity
    end
    total + self.shipping.to_f
  end
  
  def validate_cart!
    products.each do |prd|
      item = prd.item
      if item
        cart_limit = item.cart_limit(prd.options,@user) if item.respond_to?(:cart_limit) 
        
        if item.respond_to?(:update_cart_options!)
          save_changes = item.update_cart_options!(prd) 
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
  
  def shippable? 
    products.each do |prd|
      return true if prd.item.cart_shippable?
    end
    return false
  end  
  
  protected 
  
  # Need to merge the quantity options with the regular options  
  def full_options(product)
    opts = (product.options||{}).clone
    opts[:variations] = (opts[:variations]||{}).clone
    opts[:variations].merge!(product.quantity_options||{})
    opts
  end  
end
