
class Shop::ShopOrderItemSegmentField < UserSegment::FieldHandler

  def self.user_segment_fields_handler_info
    {
      :name => 'Shop Order',
      :domain_model_class => Shop::ShopOrderItem
    }
  end

  class OrderItemType < UserSegment::FieldType
    def self.select_options
      Shop::ShopOrderItem.find(:all, :select => 'item_name, order_item_id, count(*) as num_items', :conditions => {:order_item_type => 'Shop::ShopProduct'}, :group => 'order_item_id', :limit => 1000, :order => 'num_items DESC').collect { |item| [item.item_name, item.order_item_id] }.sort { |a,b| a[0] <=> b[0] }
    end

    register_operation :is, [['Item', :model, {:class => Shop::ShopOrderItemSegmentField::OrderItemType}]]

    def self.is(cls, group_field, field, item)
      item_id = item
      item_type = 'Shop::ShopProduct'
      cls.scoped(:conditions => ["#{field} = ? and order_item_type = ?", item_id, item_type])
    end

    register_operation :sum, [['Item', :model, {:class => Shop::ShopOrderItemSegmentField::OrderItemType}], ['Operator', :option, {:options => UserSegment::CoreType.number_type_operators}], ['Value', :integer]], :complex => true

    def self.sum(cls, group_field, field, item, operator, value)
      item_id = item
      item_type = 'Shop::ShopProduct'

      cls.scoped(:conditions => ["#{field} = ? and order_item_type = ?", item_id, item_type], :select => "#{group_field}, SUM(quantity) as quantity_sum", :group => group_field, :having => "quantity_sum #{operator} #{value}")
    end
  end

  register_field :num_shop_order_items, UserSegment::CoreType::CountType, :field => :end_user_id, :name => '# Shop Order Items', :display_method => 'count', :sort_method => 'count', :sortable => true
  register_field :shop_order_item, Shop::ShopOrderItemSegmentField::OrderItemType, :field => :order_item_id, :display_field => 'item_name'

  def self.sort_scope(order_by, direction)
    info = UserSegment::FieldHandler.sortable_fields[order_by.to_sym]
    sort_method = info[:sort_method]
    field = info[:field]

    if sort_method
      Shop::ShopOrderItem.scoped(:select => "end_user_id, #{sort_method}(#{field}) as #{field}_#{sort_method}", :group => :end_user_id, :order => "#{field}_#{sort_method} #{direction}")
    else
      Shop::ShopOrderItem.scoped(:order => "#{field} #{direction}")
    end
  end

  def self.get_handler_data(ids, fields)
    Shop::ShopOrderItem.find(:all, :conditions => {:end_user_id => ids}).group_by(&:end_user_id)
  end

  def self.field_output(user, handler_data, field)
    UserSegment::FieldType.field_output(user, handler_data, field)
  end
end
