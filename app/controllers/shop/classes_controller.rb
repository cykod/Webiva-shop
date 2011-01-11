
class Shop::ClassesController < ModuleController
  
  permit 'shop_manage'

  component_info 'Shop'
  
  include Shop::ShopBase

  # need to include 
   include ActiveTable::Controller   
   active_table :category_table,
                Shop::ShopProductClass,
                [ ActiveTable::IconHeader.new('', :width=>10),
                  ActiveTable::StringHeader.new('shop_product_classes.name',:label => 'Name'),
                  ActiveTable::StaticHeader.new('variation_count',:label => 'Variations'),
                  
                ]

    def class_table(display=true)

      if(request.post? && params[:table_action] && params[:class].is_a?(Hash)) 
        case params[:table_action]
        when 'delete':
          params[:class].each do |entry_id,val|
            Shop::ShopProductClass.destroy(entry_id.to_i)
          end
        end
      end

      @active_table_output = category_table_generate(params, :include => { :shop_variations => :options } )

      render :partial => 'class_table' if display
    end

    def index

    cms_page_info [ ["Content",url_for(:controller => '/content') ], ["Shop",url_for(:controller => '/shop/manage') ], ["Catalog" ,url_for(:controller => '/shop/catalog', :action => 'index') ], 
                    'Product Classes' ], "content"
         
       class_table(false)

      
    end

    def create_class
        cls = Shop::ShopProductClass.create(:name => params[:name] )
  
        class_table(true)
    end
    
    def edit 
      @cls = Shop::ShopProductClass.find(params[:path][0])
    
      cms_page_info [ ["Content",url_for(:controller => '/content') ], ["Shop",url_for(:controller => '/shop/manage') ], ["Catalog" ,url_for(:controller => '/shop/catalog', :action => 'index') ],
      [ 'Product Classes', url_for(:action => 'index' ) ], [ 'Edit %s Class',nil,@cls.name ] ], 'content'
      
    if params[:variation]
      
      @variations = params[:variation].to_a.sort { |a,b| a[0] <=> b[0] }.collect { |e| e[1] }
      @variations.each do |variation|
        order = variation[:order].split(",")
        variation[:options] = order.map { |idx| variation[:options][idx.to_s] }.compact
      end
    elsif !request.post?
      @variations = @cls.variations_hash
    else
      @variations = {}
    end 
    
    @active_currencies = get_currencies
    @available_features = [['--Select a feature to add--','']] + get_handler_options(:shop,:product_feature)

    @cls.attributes = params[:cls]
    @cls.features = params[:features_order].split(",").collect { |idx| params[:feature][idx.strip] || {} } if params[:features_order] 
    if request.post? && @cls.valid? && @cls.update_variations(@variations)
      @cls.save
      
      flash[:notice] = sprintf('Updated %s class'.t,@cls.name)
      redirect_to :action => 'index'
    end
  end      
    
  def new_variation
    render :partial => 'variation', :locals => {:variation => { :name => params[:name], :options => [], :variation_type => params[:variation_type]}, :idx => params[:idx] }
  end

  def new_option
    @active_currencies = get_currencies
    render :partial => 'option', :locals => {:option => { :name => params[:name], :weight => 0, :prices => { } }, :idx => params[:idx], :opt_idx => params[:opt_idx], :variation_type => params[:variation_type]  }
  end
end
