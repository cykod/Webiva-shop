# Copyright (C) 2010 Cykod LLC.

class Shop::WizardController < ModuleController
  
  permit 'shop_config'

  component_info 'Shop'
  
  cms_admin_paths 'website'

  def self.structure_wizard_handler_info
    { :name => "Add an E-commerce shop to your Site",
      :description => 'This wizard will add an e-commerce shop to your site complete with cart and checkout',
      :permit => "shop_config",
      :url => { :controller => '/shop/wizard' }
    }
  end

  def index
    cms_page_path ["Website"],"Add a Shop to your site structure"

    @shop_wizard = Shop::AddShopWizard.new(params[:wizard])
    
    
    @processor_count = Shop::ShopPaymentProcessor.count(:conditions => { :active => true})
    @region_count = Shop::ShopRegion.count
    @carrier_count = Shop::ShopCarrier.count

    if request.post? 
      if !params[:commit] 
        redirect_to :controller => '/structure', :action => 'wizards'
      elsif  @shop_wizard.valid?
        @shop_wizard.add_to_site!
        flash[:notice] = "Added shop to site"
        redirect_to :controller => '/structure'
      end
    else
      @shop_wizard.shop_id = Shop::ShopShop.default_shop.id
    end
  end
  

end
