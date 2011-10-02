class Shop::PageController < ParagraphController
  
  editor_header "Shop Paragraphs"
  editor_for :product_listing, :name => 'Product Listing',  :features => ['shop_product_listing'],
                                  :inputs => { :input => [ [ :product_category_1, 'Product Category', :path ] ],
                                              :detail => [ [ :product_url, 'Product URL', :path ]] },
                                  :outputs => [ [ :content_id, 'Content Identifier', :content ],
                                                [ :category_id, 'Category ID', :category_id ] ]
  editor_for :product_detail, :name => 'Product Detail', :features => ['shop_product_detail'],
                       :inputs =>  { :input =>  [ [ :product_id, 'Product URL', :path ]] ,
                                     :category => [ [ :product_category_1, 'Product Category URL', :path ] ] }, 
                        :outputs => [ [ :content_id, 'Content Identifier', :content ],
                                      [ :product_id, 'Product ID', :product_id ] ]
  editor_for :category_listing, :name => 'Category Menu',  :features => ['menu'],
                                  :inputs => [ [ :product_category_1, 'Product Category', :path ] ]

  editor_for :display_cart, :name => 'Mini Shopping Cart', :features => ['shop_display_cart']

  editor_for :category_breadcrumbs, :name => 'Category Breadcrumbs', :features => ['shop_page_category_breadcrumbs'], :inputs => [[:product_category_1, 'Product Category - Level 1', :path ] ]
  
  editor_for :search_bar, :name => 'Product Search', :features => ['shop_page_search_bar']

  def product_listing
      
    @categories = [['All Products'.t,1]] + Shop::ShopCategory.generate_list.collect  do |cat|
      [ Array.new(cat.left_index) { "--" }.join('') + cat.name, cat.id ]
    end

    @options = ProductListingOptions.new(params[:product_listing] || @paragraph.data)
      
    return if handle_module_paragraph_update(@options)

    @per_page = (1..200).to_a
    @pages = SiteNode.page_options()
  end

  
 
  class ProductListingOptions < HashModel
      attributes :base_category_id => nil, :items_per_page => 10,:detail_page_id => nil, :show_featured => false,:cart_page_id => nil, :include_category => true, :shop_shop_id => nil, :deepest_category => false
      
      page_options :detail_page_id 

      integer_options :items_per_page
      validates_presence_of :items_per_page

      boolean_options :include_category, :deepest_category
  end
    
  
  def product_detail
    @options = ProductDetailOptions.new(params[:product_detail] || @paragraph.data)
    
    return if handle_module_paragraph_update(@options)
    
    @products = [['--Use Page Connection--',nil]] + Shop::ShopProduct.find_select_options(:all,:order => 'name');   
    @pages = [['--Stage on Same Page--',nil]] + SiteNode.page_options()
    @list_pages = [['--Select List Page--',nil]] + SiteNode.page_options()
 

  end
  
  

  class ProductDetailOptions < HashModel
      attributes :product_id => nil, :cart_page_id => nil, :list_page_id => nil, :shop_shop_id => nil
      page_options :list_page_id, :cart_page_id

     canonical_paragraph "Shop::ShopProduct", :identifier, :list_page_id => :list_page_id
  end


  def category_listing
    @options = CategoryListingOptions.new(params[:category_listing] || paragraph.data)
    
    return if handle_module_paragraph_update(@options)

    @list_pages = [['--Select List Page--',nil]] + SiteNode.page_options()
    @categories = [['Root Category',1]] + Shop::ShopCategory.generate_select_list

  end
  
  class CategoryListingOptions < HashModel
      attributes :base_category_id => nil, :list_page_id => nil, :depth => 3

      page_options :list_page_id
      integer_options :depth

    validates_numericality_of :depth
      
      validates_presence_of :base_category_id,:list_page_id
  end

  def display_cart
    @options = DisplayCartOptions.new(params[:display_cart] || @paragraph.data)
    return if handle_module_paragraph_update(@options)
    @pages = [['--Please select a page--'.t,'']] + SiteNode.page_options()
  end

  class DisplayCartOptions < HashModel
    attributes :full_cart_page_id => nil
    page_options :full_cart_page_id

    validates_presence_of :full_cart_page_id
  end

  def category_breadcrumbs 
    @options = CategoryListingOptions.new(params[:category_listing] || paragraph.data)
    
    return if handle_module_paragraph_update(@options)

    @list_pages = [['--Select List Page--',nil]] + SiteNode.page_options()
    @categories = [['Root Category',1]] + Shop::ShopCategory.generate_select_list
  end
  

  class CategoryBreadcrumbsOptions < HashModel
      attributes :base_category_id => nil, :list_page_id => nil

      page_options :list_page_id
      
      validates_presence_of :base_category_id,:list_page_id
  end
  
  class SearchBarOptions < HashModel
      attributes :search_page_id => nil
      
      page_options :search_page_id
      
  end
end
