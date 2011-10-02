
class Shop::ShopProduct < DomainModel
  
  validates_presence_of :name
  validates_presence_of :shop_shop
  validates_uniqueness_of :url
  validate :price_validation
  after_update :resave_prices

  belongs_to :image_file, :class_name => 'DomainFile', :foreign_key => 'image_file_id'
  belongs_to :download_file, :class_name => 'DomainFile', :foreign_key => 'download_file_id'

  belongs_to :shop_product_class, :class_name => 'Shop::ShopProductClass'

  has_many :shop_category_products, :class_name => 'Shop::ShopCategoryProduct', :include => [ :shop_category ], :dependent => :destroy
  has_many :shop_categories, :through => :shop_category_products, :class_name => 'Shop::ShopCategory'

  has_many :prices, :class_name => 'Shop::ShopProductPrice', :dependent => :destroy
  has_many :regular_prices, :class_name => 'Shop::ShopProductPrice'
  
  has_many :shop_product_options, :class_name => 'Shop::ShopProductOption', :dependent => :destroy

  cattr_accessor :active_translation_language

  has_one :active_translation, :class_name => 'Shop::ShopProductTranslation', :conditions => :cond_func

  has_many :shop_product_translations, :class_name => 'Shop::ShopProductTranslation', :dependent => :destroy
  
  has_many :shop_product_files, :class_name => 'Shop::ShopProductFile',:dependent => :destroy
  has_many :files, :class_name=> 'Shop::ShopProductFile', :conditions => 'file_type = "doc"', :order => 'position'
  has_many :images, :class_name=> 'Shop::ShopProductFile', :conditions => 'file_type = "img"', :order => 'position'
  
  has_many :shop_product_features, :class_name => 'Shop::ShopProductFeature', :foreign_key => 'shop_product_id', :dependent => :destroy
  has_many :shop_coupon_products, :class_name => "Shop::ShopCouponProduct", :dependent => :destroy

  cached_content :identifier => :url
  content_node :container_type => 'Shop::ShopShop', :container_field => 'shop_shop_id', :push_value => true 

  belongs_to :shop_shop, :class_name => 'Shop::ShopShop'

  def identifier; self.url; end

  def content_node_body(language)
    %w(sku internal_sku name name_2 description detailed_description brand url).map do |fld|
      self.send(fld)
    end.compact.join("\n\n")
  end

  def content_description(language)
    "Shop Product".t
  end

  def title
    self.name
  end

  # return the deepest category a product belongs to - helpful for searches
  # or indexes
  def deepest_category
    left_index, cat = self.shop_categories.inject([-1,nil]) do |cur,cat| 
      if cat && cat.left_index > cur[0]
        [ cat.left_index, cat ]
      else
        cur
      end
    end

    return cat
  end

  # returns a category/url path using the deepest category
  def category_url
    cat = self.deepest_category
    if cat
      "#{cat.url}/#{url}"
    else
      "-/#{url}"
    end
  end
  
  # Return the products features + the features of it's product class
  def full_features
    self.features + (self.shop_product_class ? self.shop_product_class.shop_product_features : []).to_a +
       self.shop_shop.shop_product_features
  end
  
  before_validation :create_url 
  
  @@callbacks = [ :price,:purchase,:stock,:shipping,:rendering,:update_cart,:other ]
  
  def copy_product
    new_prd = self.clone
    new_prd.url = nil
    new_prd.created_at = nil
    new_prd.updated_at = nil
    new_prd.price_values = self.price_values
    new_prd.name = self.name + " (COPY)".t
    new_prd.save
    
    # Clone all the has manys
    %w(shop_category_products prices shop_product_options shop_product_translations shop_product_files shop_product_features).each do |rel|
      new_prd.send("#{rel}=", self.send(rel).collect { |itm| new_itm = itm.clone; new_itm.shop_product_id=new_prd.id; new_itm })
    end

    new_prd
  end
  
  def caption=(caps)
    @captions = caps
  end

  def files_ids=(ids)
    @file_ids = ids.split(",").select { |elm| !elm.blank? } unless ids.nil?
  end
  
  def images_ids=(ids)
    @image_ids = ids.split(",").select { |elm| !elm.blank? } unless ids.nil?
  end
  
  
  def files_product_files
    if @file_ids && @file_ids.is_a?(Array) && @file_ids.length > 0
      @file_ids.collect { |fl|
        Shop::ShopProductFile.new( :file_type => 'doc', :domain_file_id => fl, :description => @captions[fl.to_s] )
      }
    else
      self.files
    end
  end
  
  def image
    self.image_file
  end
  
  def images_product_files
    if @image_ids && @image_ids.is_a?(Array)
      @image_ids.collect { |fl|
        Shop::ShopProductFile.new( :file_type => 'img', :domain_file_id => fl, :description => @captions[fl.to_s] )
      }
    else
      self.images
    end
  end
  
  def features
    if @features_cache
      @features_cache
    else
      self.shop_product_features
    end    
  end
  
  def features=(val)

    idx = 0
    @features_cache = val.collect do |elm|
      elm = elm.clone
      pf = self.shop_product_features.find_by_id(elm[:id]) || self.shop_product_features.build
      hndler = get_handler_info(:shop,:product_feature,elm[:shop_feature_handler])
      pf.shop_feature_handler = hndler[:identifier]
      pf.position = idx
      idx+=1
      elm.delete(:id)
      elm.delete(:shop_feature_handler)
      pf.attributes = elm
      pf
    end
    
  end

  def price_validation
    Shop::ShopProduct.active_currencies.each do |cur|
      price = self.regular_prices.detect { |prc| prc.currency == cur }
      if !price || price.price.blank?
        self.errors.add(:price_values,"is missing #{cur}")
      end
    end
  end

  def resave_prices
    self.regular_prices.each do |prc|
      prc.save if prc.changed?
    end
  end
  
  def validate
    ok = self.features.to_a.inject(true) do |ok,feature|
      ok && feature.options.valid?
    end
    
    errors.add(:features,'are invalid')  if !ok
  end
  
  def before_save
    @@callbacks.each do |cbk|
      self.send("#{cbk}_callbacks=",0)
    end
    
    # Update the callback count for the features
    self.full_features.each do |feat|
      feat.update_callbacks
      @@callbacks.each do |cbk|
        self.send("#{cbk}_callbacks=",self.send("#{cbk}_callbacks") + (feat.send("#{cbk}_callback?") ? 1 : 0) )
      end
    end
  end
  
  
  def after_save
    if @features_cache
      @features_cache.each { |feat| feat.feature_options = feat.options.to_h; feat.save } 
      self.shop_product_features = self.features
    end
    
    if @file_ids
      Shop::ShopProductFile.transaction do 
        touched_files = []
        @file_ids.each_with_index do |fid,idx|
          spf = shop_product_files.detect { |prd| prd.domain_file_id == fid.to_i } || 
                     self.shop_product_files.build(:domain_file_id => fid.to_i, :file_type => 'doc')
          spf.description = @captions[fid.to_s]
          spf.position = idx
          spf.save        
          touched_files << fid.to_i
        end
        self.files.each { |spf|  spf.destroy unless touched_files.include?(spf.domain_file_id) }
      end
      ## update file ids
    end
    Shop::ShopProductFile.transaction do 
      if @image_ids
        touched_images = []
        @image_ids.each_with_index do |fid,idx|
          spf = shop_product_files.detect { |prd| prd.domain_file_id == fid.to_i } || 
                     self.shop_product_files.build(:domain_file_id => fid.to_i, :file_type => 'img')
          spf.description = @captions[fid.to_s]
          spf.position = idx
          spf.save        
          touched_images << fid.to_i
        end
        self.images.each { |spf|  spf.destroy unless touched_images.include?(spf.domain_file_id) }
      end
    end
  end
  
  def self.active_currencies
     @mod_opts ||= Shop::AdminController.module_options
     [@mod_opts.shop_currency || 'USD' ]
  end


  def price_values=(price_hsh)
    price_hsh ||= {}
    price_hsh.each do |new_currency,new_price|
      price = self.regular_prices.detect { |prc| prc.currency == new_currency } || self.regular_prices.build(:currency => new_currency)
      price.price = new_price
    end

  end

  # returns a hash of non-sale prices of the product
  def price_values
    price_hash = {}
    Shop::ShopProduct.active_currencies.each { |cur| price_hash[cur] = nil }
    self.regular_prices.each { |price| price_hash[price.currency] = price.price }
    price_hash
  end
 
  def get_price(currency,user=nil)
    price = self.prices.detect { |pr| pr.currency == currency }

    return nil unless price
    
    price = price.clone
    if self.price_callbacks > 0
      self.full_features.each do |feat|
        if feat.price_callback?
          price.price = feat.feature_instance.price(currency,price.price,user)
        end
      end
    end
    return price
  end
  
  def unit_cost(currency,user=nil)
    prc = get_price(currency,user)
    prc.price if prc
  end

  alias_method :get_unit_cost, :unit_cost

  def localized_price(currency,quantity=1,user=nil)
    price = get_price(currency,user)
    if price 
      price.localized_price(quantity)
    else
      nil
    end
  end
  
  def variations
    return [] unless self.shop_product_class
    self.shop_product_class.shop_variations
  end
  
  def option_variations
    return [] unless self.shop_product_class
    self.shop_product_class.option_variations
  end
  
  def quantity_variations
    return [] unless self.shop_product_class
    self.shop_product_class.quantity_variations
  end
  
  def get_variation_details(variation)
    var_opts = variation.options.find(:all,:joins => :product_options, :conditions => ['shop_product_options.shop_product_id = ?',self.id],:order => 'shop_variation_options.option_index')
    opts = self.shop_product_options.index_by(&:shop_variation_option_id)
    
    var_opts.map do |var_opt|
      { :var =>  var_opt, :opt =>  opts[var_opt.id] }
    end
  end

  def get_variation_options(variation,currency) 
     prd_opts = self.shop_product_options.index_by(&:shop_variation_option_id)
     opts = variation.options
     
     if variation.variation_type == 'option'
       opts.collect do |opt|
        prd_opt = prd_opts[opt.id]
        if(prd_opt && prd_opt.override?)
          price = prd_opt.prices[currency].to_f
        else
          price = opt.prices[currency].to_f
        end
        [ opt.name, price,opt.id, prd_opt ? prd_opt.in_stock? : true ]
       end
     else
       last_amount = 0
       opts.collect do |opt|
        prd_opt = prd_opts[opt.id]
        if(prd_opt)
          price = prd_opt.prices[currency].to_f
          max = prd_opt.override? ? prd_opt.max : opt.max 
          min = last_amount + 1
          nm = max ? "#{last_amount + 1}-#{max}" : "#{last_amount + 1}+"
          last_amount = max
          [ opt.name,nm, price, min, max ]
        else
          nil
        end
       end.compact
     end
  end
  
  def update_cart_options!(cart_item,cart)
    quantity_options = (cart_item.quantity_options||{}).clone
    
    save_changes = false
    
    # Handle quantity variations - we are going to set the shop variation option id based on quantity
    self.quantity_variations.each do |var|
      var.options.each do |opt|
        
        # Find the associated product option
        popt = self.shop_product_options.detect { |spo| spo.shop_variation_option_id == opt.id }
        
        # see if the product option is overriding the max
        max = popt && popt.override? ? popt.max : opt.max
        
        # if we have a # of the item is less than the max, 
        if !max || cart_item.quantity <= max
          # then we can see the product variation
          if quantity_options[var.id] != opt.id 
            quantity_options[var.id] = opt.id
            save_changes = true
          end
          break
        end
      end
    end
    cart_item.quantity_options = quantity_options
    
    if self.update_cart_callbacks > 0
      self.full_features.each do |feat|
        if feat.update_cart_callback?
          save_changes ||= feat.feature_instance.update_cart(cart_item)
        end
      end
    end
    
    
    return save_changes
  end
  
  def cart_details(options,cart)
    vars = self.variations
    description = []
    return '' unless options.is_a?(Hash) && options[:variations].is_a?(Hash)
    vars.each do |variation|
    
      option_id = (options[:variations]||{})[variation.id]
      opt = variation.options.find_by_id(option_id)
      if opt
        description << opt.name
      end
    end
    description.join(", ")
  end
  
  # get the price for a certain set of ShopVariationOptions
  # (must of the ShopProductOption include
  def get_options_price(options,currency,user=nil)
    cost = get_unit_cost(currency,user)
    options.each do |info|
      opt = info[0]
      variation_type = info[1]
      
      if variation_type == 'option'
        if(opt.product_options[0] && opt.product_options[0].override?)
         cost += opt.product_options[0].prices[currency].to_f
        else
         cost += opt.prices[currency].to_f
        end
      else
        cost = opt.product_options[0].prices[currency].to_f
      end
    end
    cost
  end
  
  def cart_sku 
    self.internal_sku || self.sku
  end
  
  # return the price of the product with the given options hash
  def cart_price(options,cart)
    return get_unit_cost(cart.currency,cart.user) unless options.is_a?(Hash) && options[:variations].is_a?(Hash)
    opts = []
    options[:variations].each do |variation_id,variation_option_id|
     variation = self.variations.detect { |var| var.id ==  variation_id.to_i }
     opt = variation.options.find_by_id(variation_option_id,:include => :product_options, :conditions => ['shop_product_options.shop_product_id = ?',self.id],:order => 'shop_variation_options.option_index')  if variation
      opts << [ opt,variation.variation_type ] if opt 
    end
    get_options_price(opts,cart.currency,cart.user)
  end
  
  def cart_limit(options,cart)
    limit = 10000000
    return 0 if !self.in_stock?
    if self.stock_callbacks > 0
      self.full_features.each do |feat|
        if feat.stock_callback?
          lim = feat.feature_instance.stock(options,cart.user)
          limit = lim if lim < limit
        end
      end
    end
    limit
  end
  
  def cart_shippable?
    self.shippable?
  end

  def cart_taxable?
    self.taxable?
  end
  
  def cart_post_processing(user,order_item,session)
    redirect_location = nil
    if self.purchase_callbacks > 0
      self.full_features.each do |feat|
        if feat.purchase_callback?
          feat_instance = feat.feature_instance
          feat_instance.purchase(user,order_item,session)
          if feat_instance.redirect_location
            redirect_location = feat_instance.redirect_location
          end          
        end
      end
    end
    
    { :redirect => redirect_location }
  end 
  

  def cond_func
    "language='#{Shop::ShopProduct.active_translation_language}'"
  end

  def category_tree
    return @category_tree if @category_tree
    @category_tree = Shop::ShopCategory.generate_tree(self.id)
  end

  def add_category(category,featured = false)
    category=category.id if category.is_a?(Shop::ShopCategory)

    cp = self.shop_category_products.find_by_shop_category_id(category)
    if(!cp)
      self.shop_category_products.create(:shop_category_id => category,:featured => featured)
    else cp.featured? != featured
      cp.update_attribute(:featured, featured)
    end
  end

  def remove_category(category)
    category=category.id if category.is_a?(Shop::ShopCategory)

    if(cp = self.shop_category_products.find_by_shop_category_id(category))
      cp.destroy
    end
  end
  
  def self.run_search(shop_shop_id,search_params,page=1)
  
    terms = search_params.split(/( |,)/).map { |elm| elm.strip }.find_all { |elm| elm!="" && elm != ',' }
    match_terms = terms.join(" ")
    
    fields = ["`sku`",  "`name`", "`description`","`internal_sku`","`detailed_description`" ]
    cond = [ " ( " +  terms.map { |elm| fields.map { |fld| "#{fld} LIKE #{self.connection.quote("%#{elm}%")}" }.join(" OR ")  }.join(" OR ") + ") AND shop_shop_id=?", shop_shop_id ]
  
    Shop::ShopProduct.paginate(page,:order => "MATCH(`name`,`description`,`internal_sku`,`detailed_description`) AGAINST (" + self.connection.quote(terms) + " IN BOOLEAN MODE) DESC" ,:include => [ :prices ], :conditions => cond )
  end


  # build and save a deep clone of self
  def dup
    prd = self.clone
    prd.save 
    self.shop_category_products.each do |scp|
      prd.shop_category_products.create(:shop_category_id => scp.shop_category_id)
    end
    self.shop_product_translations.each do |spt|
      new_spt = spt.clone
      new_spt.shop_product_id= prd.id
      new_spt.save
    end

    prd
  end


  protected

 def create_url
   if self.url.blank?
     name_base = self.name.to_s.downcase.gsub(/[ _]+/,"-").gsub(/[^a-z+0-9\-]/,"")
     if name_base != self.url
       cnt = 2
       name_try = name_base

       if check_duplicate(name_try) && !self.sku.blank?
         name_try = name_base = name_base + "-" + self.sku.to_s.downcase.gsub(/[ _]+/,"-").gsub(/[^a-z+0-9\-]/,"")
       end

       while check_duplicate(name_try)
         name_try = name_base + '-' + cnt.to_s
         cnt += 1
       end
       self.url = name_try
     end
   else
     self.url = self.url.downcase.gsub(/[ _]+/,"-").gsub(/[^a-z+0-9\-]/,"")
   end

   if !self.shop_shop
    self.shop_shop = Shop::ShopShop.default_shop
   end
 end


 def check_duplicate(url_try)
   if self.id.blank?
    Shop::ShopProduct.find(:first,:conditions => ['`url`=? ',url_try])
   else
     Shop::ShopProduct.find(:first,:conditions => ['`url`=? AND id != ? ',url_try,self.id])
   end

   
 end


end
