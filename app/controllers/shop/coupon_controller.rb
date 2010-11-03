
class Shop::CouponController < ModuleController
  
  permit 'shop_manage'

  component_info 'Shop'
  
  cms_admin_paths 'content',
                  'Content' => { :controller => '/content' },
                  'Shop' => { :controller => '/shop/manage' },
                  'Coupons' => { :action => 'index' }
  
  include ActiveTable::Controller
  active_table :coupon_table,
            Shop::ShopCoupon,
            [ :check, :internal_name, :cart_name, :code, hdr(:date_range,'expires_at'), "Discount", 
              hdr(:date_range,'shop_coupons.created_at'), hdr(:boolean,'shop_coupons.active') ]
  
  def display_coupon_table(display = true)

    active_table_action("coupon") do |act,cids| 
      coupons = Shop::ShopCoupon.find(cids)
      case act
      when "delete": coupons.map(&:destroy)
      when "activate": coupons.map(&:activate!)
      when "deactivate": coupons.map(&:deactivate!)
      end
    end

    @tbl = coupon_table_generate params, :order => 'shop_coupons.created_at DESC'
    render :partial => 'coupon_table' if display
  end
  
  def index
    cms_page_path ['Content','Shop'],'Coupons' 


    display_coupon_table(false)
  end
  
  def edit
    @coupon = Shop::ShopCoupon.find_by_id(params[:path][0]) || Shop::ShopCoupon.new
    cms_page_path ['Content','Shop','Coupons' ], @coupon.id ? ["Edit %s",nil,@coupon.internal_name] : "Create Coupon"
    
    if request.post? && params[:coupon]
      if @coupon.update_attributes(params[:coupon])
        flash[:notice] = "Saved '%s'" / @coupon.internal_name
        redirect_to :action => :index
      end
    end
  
  end
  
end

  
  
