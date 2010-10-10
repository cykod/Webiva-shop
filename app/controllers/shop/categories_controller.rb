
class Shop::CategoriesController < ModuleController
  component_info 'Shop'


  permit 'shop_manage'

  def index
     cms_page_info [ ["Content",url_for(:controller => '/content') ], ["Shop",url_for(:controller => '/shop/manage') ], "Categories" ], "content"
    Shop::ShopCategory.get_root_category
    @root_category = Shop::ShopCategory.generate_tree
  
  end


  def add_category
    @category = Shop::ShopCategory.create(:name => params[:title], :parent_id => params[:parent_id] )  
  
    render :partial => 'category', :locals => { :cat => @category, :last => true }

  end

  def edit_category_title
    @category = Shop::ShopCategory.find(params[:category_id])

    @category.update_attributes(:name => params[:title])

    render :nothing => true
  end

  def move_category
    @category = Shop::ShopCategory.find(params[:category_id])

    @category.update_attribute(:parent_id ,params[:parent_id])

    render :nothing => true
    
  end
  


  def category_info
    @category = Shop::ShopCategory.find(params[:category_id])
    
    if request.post? && params[:category]
      @category.update_attributes(params[:category])
      flash.now[:notice] = 'Updated Category'    
    end

    render :partial => 'category_info'
  end

  def remove_category
    @category = Shop::ShopCategory.find(params[:category_id])

    @category.destroy

    render :nothing => true
  end

end
