
class Shop::StandardCarrierProcessor 

  def initialize(options)
    @options = options
  end
  
  def calculate_shipping(cart)
    total = 0.0
    
    cart_items = cart.products
    # Only calculate on the shippable items
    cart_items = cart_items.find_all { |item| item.item.cart_shippable? }
    
    case @options[:shipping_calculation]
    when 'total':
          total = total_cost(cart.shippable_total)
    when 'weight':
      if @options[:weights_shipping_cost] == 'item'
          # Go through each item, figure the weight and then the cost
          cart_items.each do |item|
            total += weight_cost(item.shop_product.weight) * item.quantity
          end
      elsif @options[:weights_shipping_cost] == 'order'
          # Add weight of all the items together, then figure out the cost
          total_weight = 0.0
          cart_items.each do |item|
              total_weight += item.shop_product.weight.to_f * item.quantity
          end
          total = weight_cost(total_weight)
      end
    when 'items':
      item_count = cart_items.inject(0.0) { |tot,item| tot + item.quantity }
      case @options[:items_shipping_cost]
      when "order":
        # count the total # of items, find the cost
        total = item_cost(item_count)
      when "item":
        # count the total # of items, find the cost * # of items
        total = item_cost(item_count) * item_count
      when "incremental":
        # go through each items, find the cost of the individual item by it's index, add together 
        (1..item_count).to_a.each do |item_index|
          total += item_cost(item_index)
        end
      end
    when 'class':
      case @options[:classes_shipping_cost]
      when "item"
        # go through each item, calculate the cost, total it up
        cart_items.each do |item|
          total += class_cost(item.shop_product.shop_product_class_id) * item.quantity
        end
      when "order"
        # go through each of the items, add it to a hash if it doesn't exist already
        # add up each of the hashes
        cart_classes = cart_items.inject({}) { |hsh,item| hsh[item.shop_product.shop_product_class_id.to_s] = true }
        cart_classes.each do |cls,exists|
          total += class_cost(cls) 
        end
      end
    end
    
    total
    
  end

  def self.shop_carrier_processor_handler_info
    { :name => "Standard Carrier" }
  end
  
  
  def self.get_options(hsh)
    Shop::StandardCarrierProcessor::Options.new(hsh)
  end

  def self.validate_options(opts)
    opts.valid?
  end
  
  class Options < HashModel
    default_options :weights => [], :weight_prices => [], :items => [], :item_prices => [], :total_prices => [], :totals => [], :class_prices => {}, :shipping_calculation => nil, :items_shipping_cost => 'order', :weights_shipping_cost => 'order', :classes_shipping_cost => 'item'
    
    validates_presence_of :shipping_calculation
  end
  
  def self.options_partial
    "/shop/config/standard_carrier_processor_options"
  end
  
  protected
  
  def weight_cost(weight)
    @options[:weights].each_with_index do |option_weight,index|
      return @options[:weight_prices][index].to_f if weight < option_weight.to_f
    end
    return @options[:weight_prices][-1].to_f
  end
  
  def item_cost(item_num)
    @options[:items].each_with_index do |option_item,index|
      return @options[:item_prices][index].to_f if item_num < option_item.to_i
    end
    return @options[:item_prices][-1].to_f
  end
  
  def class_cost(item_class)
    if @options[:class_prices][item_class.to_s]
      return @options[:class_prices][item_class.to_s].to_f
    else
      return @options[:class_prices]["0"].to_f
    end
  end
  
  def total_cost(item_num)
    @options[:totals].each_with_index do |option_item,index|
      return @options[:total_prices][index].to_f if item_num < option_item.to_i
    end
    return @options[:total_prices][-1].to_f
  end  
  
end
