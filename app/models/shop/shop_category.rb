
# Left index 
# - all children of a element have the same left index,
# - all children of an element have a higher left index than the element itself
class Shop::ShopCategory < DomainModel
  

  has_many :children, :class_name => 'Shop::ShopCategory', :order => 'name', :foreign_key => 'parent_id', :dependent => :destroy
  belongs_to :parent, :class_name => 'Shop::ShopCategory', :foreign_key => 'parent_id'

  has_many :shop_category_products, :class_name => 'Shop::ShopCategoryProduct'

  has_many :featured_shop_category_products, :class_name => 'Shop::ShopCategoryProduct', :conditions => 'shop_category_products.featured = 1'

  has_many :unfeatured_shop_category_products, :class_name => 'Shop::ShopCategoryProduct', :conditions => 'shop_category_products.featured = 0'

  attr_accessor :nested_children_arr

  def self.get_root_category
    self.find(:first,:conditions => 'parent_id=0') || self.create(:name => 'Categories'.t, :parent_id => 0)
  end

  def self.generate_tree( product_id = nil)

    if product_id.is_a?(Array)
      elements = self.find(:all,:select =>     'shop_categories.*,COUNT(shop_category_products.shop_product_id) as shop_product_id,SUM(shop_category_products.featured) as featured',
                                :joins => " LEFT JOIN shop_category_products ON (shop_category_products.shop_product_id = #{Shop::ShopCategory.connection.quote(product_id)} AND shop_category_products.shop_category_id = shop_categories.id )",
                                :order => 'left_index,name')
    elsif product_id
      elements = self.find(:all,:select => 'shop_categories.*,shop_category_products.shop_product_id,shop_category_products.featured',
                                :joins => " LEFT JOIN shop_category_products ON (shop_category_products.shop_product_id = #{Shop::ShopCategory.connection.quote(product_id)} AND shop_category_products.shop_category_id = shop_categories.id )",
                                :order => 'left_index,name')
    else
      elements = self.find(:all,:order => 'left_index,name')
    end
    children_hash = {}

    ret_arr = []
  
    elements.each do |child|
      child.nested_children_arr = []
      children_hash[child.id] = child.nested_children_arr

      if child.parent_id > 0
        children_hash[child.parent_id] << child if children_hash[child.parent_id]
      else
        ret_arr << child
      end
    end

    
  
    return ret_arr[0]
  end

  def self.generate_list
    base_category = self.generate_tree

    if base_category
      base_category.generate_child_list 
    else
      []
    end
  end
  
  def self.generate_select_list
    generate_list.collect do |cat|
      ["- " * cat.left_index + cat.name, cat.id ]
    end
  end

  def generate_child_list
    self.nested_children.inject([]) do |arr,chld|
      arr += [ chld ] + chld.generate_child_list
    end
  end

  public

  def nested_children
    self.nested_children_arr ? self.nested_children_arr : children
  end


  def before_save
    if self.parent_id.to_i > 0
      self.left_index = self.parent.left_index + 1
    else
      self.left_index = 0
    end  
  end

  def after_save
    self.children.each do |child|
      child.save
    end
  end

  def find_products(product_type,opts = {})

    case product_type 
      when :featured; featured = 'shop_category_products.featured=1'
      when :unfeatured; featured = 'shop_category_products.featured=0'
      else; featured = '1'
    end
    if opts[:conditions]
      opts[:conditions] = [ opts[:conditions] ] if opts[:conditions].is_a?(String)
      opts[:conditions] = [ "shop_category_id=? AND #{featured} AND (" + options[:conditions][0] + ")" ] + [ self.id ] + opts[:conditions][1..-1]
    else
      opts[:conditions] = [ "shop_category_id=? AND #{featured} " , self.id ]
    end
  
    opts[:order] = 'shop_products.name'
    opts[:include] = [ :shop_product ]

    Shop::ShopCategoryProduct.find(:all,opts)
  end
  
 def paginate_products(product_type,opts = {})

    case product_type 
      when :featured; featured = 'shop_category_products.featured=1'
      when :unfeatured; featured = 'shop_category_products.featured=0'
      else; featured = '1'
    end
    if opts[:conditions]
      opts[:conditions] = [ opts[:conditions] ] if opts[:conditions].is_a?(String)
      opts[:conditions] = [ "shop_category_id=? AND #{featured} AND (" + options[:conditions][0] + ")" ] + [ self.id ] + opts[:conditions][1..-1]
    else
      opts[:conditions] = [ "shop_category_id=? AND #{featured} " , self.id ]
    end
    opts[:order] = 'shop_products.name'
    opts[:include] = [ :shop_product ]

    page = opts.delete(:page)
    Shop::ShopCategoryProduct.paginate(page,opts)
  end  
end
