
class Shop::ShopProductClass < DomainModel

  validates_presence_of :name

  has_many :shop_products, :class_name => "Shop::ShopProduct"  
  has_many :shop_variations, :class_name => 'Shop::ShopVariation', :dependent => :destroy, :order => 'variation_type = "option"'
  
  has_many :option_variations , :class_name => 'Shop::ShopVariation', :conditions => "variation_type = 'option'"
  has_many :quantity_variations , :class_name => 'Shop::ShopVariation', :conditions => "variation_type = 'quantity'"


  has_many :shop_product_features, :class_name => 'Shop::ShopProductFeature', :dependent => :destroy
  
  def before_destroy
    self.shop_products.each do |prd|
      prd.update_attribute(:shop_product_class_id,nil)
    end
  end


  def variations_hash
    self.shop_variations.collect do |variation|
      var = variation.attributes.symbolize_keys
      var[:options] = variation.options.collect do |opt|
        opt.attributes.symbolize_keys
      end
      var
    end
  end


  def after_save
   DataCache.expire_content("Shop::ShopProduct")
  end

  
  def update_variations(variation_hash)
    deleted_variation_ids = self.shop_variation_ids
    variation_hash.each do |variation_data|
      if variation_data[:id] && !variation_data[:id].blank?
        deleted_variation_ids.delete(variation_data[:id].to_i)
        variation = self.shop_variations.find(variation_data[:id])
      else
        variation = self.shop_variations.build
      end
      variation.name = variation_data[:name]
      variation.variation_type = variation_data[:variation_type]
      variation.save
      
      deleted_option_ids = variation.option_ids
      
      (variation_data[:options] || []).each_with_index do |opt_hsh,idx|
        if(opt_hsh[:id] && !opt_hsh[:id].blank?)
          opt = variation.options.find(opt_hsh[:id])
          deleted_option_ids.delete(opt_hsh[:id].to_i)
        else
          opt = variation.options.build
        end
        prices  = {}
        (opt_hsh[:prices]||[]).each { |currency,price| prices[currency] = price.to_f }
        opt.attributes = { :name => opt_hsh[:name],
                           :weight => opt_hsh[:weight],
                           :prices => prices,
                           :max => opt_hsh[:max],
                           :option_index => idx }
        opt.save
      end
      
      Shop::ShopVariationOption.destroy(deleted_option_ids)
    end
    Shop::ShopVariation.destroy(deleted_variation_ids)
    
  end

  def validate
    ok = self.features.to_a.inject(true) do |ok,feature|
      ok && feature.options.valid?
    end
    
    errors.add(:features,'are invalid')  if !ok
  end

  def features
    @features_cache || self.shop_product_features
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

  def after_save
    if @features_cache
      @features_cache.each { |feat| feat.feature_options = feat.options.to_h; feat.save } 
      self.shop_product_features = self.features
    end
  end
end
