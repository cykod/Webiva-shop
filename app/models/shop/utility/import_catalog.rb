require 'csv'

class Shop::Utility::ImportCatalog < HashModel
  attributes :import_file_id => nil, :file_folder_id => nil
  
  validates_presence_of :import_file_id,:file_folder_id


  @@columns = %w(sku internal_sku name description cat1 cat2 cat3 cat4 unit_quantity shop_product_class_id price image_file).map { |elm| elm.to_sym }
  
  
  
  def run_import
  
    # Open the CSV file
    
    classes = Shop::ShopProductClass.find(:all).index_by(&:name)
    root_category = Shop::ShopCategory.generate_tree
    images = DomainFile.find(:all,:conditions => { :parent_id => self.file_folder_id }).index_by(&:name)
    
    
    df = DomainFile.find(self.import_file_id)
    if df.extension == 'xls'
      filename = df.generate_csv 
    else
      filename = df.filename
    end
    reader = CSV.open(filename,"r",',')
    
    reader.shift # Get rid of title
    
    @mod_opts = Shop::AdminController.module_options
    
    actions = []
    reader.each do |row|
      data,opt_data = get_data(row)
      
      errs = []
      if classes[data[:shop_product_class_id]]
        data[:shop_product_class_id] = classes[data[:shop_product_class_id]].id
      elsif !data[:shop_product_class_id].blank?
        errs << "Invalid Product Class:" + data[:shop_product_class_id]
      end
      
      
      if images[data[:image_file]]
        data[:image_file_id] =  images[data[:image_file]].id
      elsif !data[:image_file].blank?
        errs << "Invalid Image: " + data[:image_file]
      end
      
      prd = Shop::ShopProduct.find_by_internal_sku(data[:internal_sku]) || Shop::ShopProduct.new
      act =  prd.id ? 'update' : 'create'
      
      prd.update_attributes(data.slice(:name,:description,:sku,:internal_sku,:unit_quantity,:shop_product_class_id,:image_file_id))
      
      if prd.id
        add_categories(prd,data,root_category,errs)
        prd.set_prices({ @mod_opts.shop_currency => data[:price].to_f })
        set_options(prd,opt_data)
      end
    
      actions << [ act, prd, errs ] if prd.id
    end
    reader.close
    
    actions
  end
  
  protected
  
  def set_options(prd,options_data)
    offset = 0
    if prd.shop_product_class
      prd.shop_product_class.quantity_variations.each_with_index do |variation,index| 
        variation.options.each_with_index do |var_opt,index|
          opt = prd.shop_product_options.find_by_shop_variation_option_id(var_opt.id) ||
                prd.shop_product_options.build(:shop_variation_option_id => var_opt.id)
                
          max = options_data[offset]
          price = options_data[offset+1]
          
          opt.attributes = { :max => max,  :prices => { @mod_opts.shop_currency => price ? price.to_f : nil }, :override => ( max ? true : false )   }
          opt.save
          
          offset += 2
        end
      end  
      
      prd.shop_product_class.option_variations.each_with_index do |variation,index|
        variation.options.each_with_index do |var_opt,index|
          opt = prd.shop_product_options.find_by_shop_variation_option_id(var_opt.id) ||
                prd.shop_product_options.build(:shop_variation_option_id => var_opt.id)
          
          sku = options_data[offset]
          price = options_data[offset+1]
          weight_adj = options_data[offset+2]
          image_id = options_data[offset+3]
          
          opt.attributes = { :option_sku => sku, :prices =>  { @mod_opts.shop_currency => price ? price.to_f : nil },
                             :weight => weight_adj, :image_id => image_id,
                             :override => (( weight_adj || price ) ? true : false ) }
          opt.save
          offset += 4
        end
      end
    end  
  end
  
  def add_categories(prd,data,parent_category,errs)
    prd.shop_category_products = [] # Clear the categories
    [ :cat1, :cat2, :cat3, :cat4].each do |cat|
      cat = data[cat].to_s.strip
      if !cat.blank?
        parent_category.nested_children_arr ||= []
        category = parent_category.nested_children_arr.detect { |category| category.name == cat }
        if !category
          category = Shop::ShopCategory.create(:name => cat, :parent_id => parent_category.id)
          parent_category.nested_children_arr << category
          errs << "Created Category: " + category.name
        end
        prd.add_category(category)
        parent_category = category
      end
    end
  end
  
  def get_data(row)
    data = {}
    @@columns.each_with_index { |fld,idx| data[fld] = row[idx] }
    [ data, row[-(row.length - @@columns.length)..-1] ] 
  end


  
end
