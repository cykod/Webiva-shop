
class Shop::ShopProductFile < DomainModel

  belongs_to :shop_product
  
  acts_as_list :scope => 'file_type'

  belongs_to :domain_file
end
