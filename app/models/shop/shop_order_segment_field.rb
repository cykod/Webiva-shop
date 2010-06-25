
class Shop::ShopOrderSegmentField < UserSegment::FieldHandler
  extend ActionView::Helpers::NumberHelper

  def self.user_segment_fields_handler_info
    {
      :name => 'Shop Order',
      :domain_model_class => Shop::ShopOrder
    }
  end

  class StateType < UserSegment::FieldType
    def self.select_options
      Shop::ShopOrder.state_select_options
    end

    register_operation :is, [['State', :model, {:class => Shop::ShopOrderSegmentField::StateType}]]

    def self.is(cls, group_field, field, source)
      cls.scoped(:conditions => ["#{field} = ?", source])
    end
  end

  class PaymentType < UserSegment::FieldType
    def self.select_options
      Shop::ShopOrder.payment_type_select_options
    end

    register_operation :is, [['Payment Type', :model, {:class => Shop::ShopOrderSegmentField::PaymentType}]]

    def self.is(cls, group_field, field, source)
      cls.scoped(:conditions => ["#{field} = ?", source])
    end
  end

  register_field :num_shop_orders, UserSegment::CoreType::CountType, :field => :end_user_id, :name => '# Shop Orders', :display_method => 'count', :sort_method => 'count', :sortable => true
  register_field :shop_order_total, UserSegment::CoreType::NumberType, :field => :total, :name => 'Order Total', :display_method => 'sum', :sort_method => 'sum', :display_methods => [['Order Total (Max)', 'max'], ['Order Total (Min)', 'min']], :sort_methods => [['Order Total (Max)', 'max'], ['Order Total (Min)', 'min']], :sortable => true
  register_field :shop_order_state, Shop::ShopOrderSegmentField::StateType, :field => :state, :name => 'Order State'
  register_field :shop_ordered_at, UserSegment::CoreType::DateTimeType, :field => :ordered_at, :display_method => 'max', :sort_method => 'max', :display_methods => [['Ordered at (First)', 'min']], :sort_methods => [['Ordered at (First)', 'min']], :sortable => true
  register_field :shop_shipped_at, UserSegment::CoreType::DateTimeType, :field => :shipped_at, :display_method => 'max', :sort_method => 'max', :display_methods => [['Shipped at (First)', 'min']], :sort_methods => [['Shipped at (First)', 'min']], :sortable => true
  register_field :shop_order_subtotal, UserSegment::CoreType::NumberType, :field => :subtotal, :name => 'Order Subtotal', :display_method => 'sum', :sort_method => 'sum', :display_methods => [['Order Subtotal (Max)', 'max'], ['Order Subtotal (Min)', 'min']], :sort_methods => [['Order Subtotal (Max)', 'max'], ['Order Subtotal (Min)', 'min']], :sortable => true
  register_field :shop_order_shipping, UserSegment::CoreType::NumberType, :field => :shipping, :name => 'Order Shipping', :display_method => 'sum', :sort_method => 'sum', :display_methods => [['Order Shipping (Max)', 'max'], ['Order Shipping (Min)', 'min']], :sort_methods => [['Order Shipping (Max)', 'max'], ['Order Shipping (Min)', 'min']], :sortable => true
  register_field :shop_order_tax, UserSegment::CoreType::NumberType, :field => :tax, :name => 'Order Tax', :display_method => 'sum', :sort_method => 'sum', :display_methods => [['Order Tax (Max)', 'max'], ['Order Tax (Min)', 'min']], :sort_methods => [['Order Tax (Max)', 'max'], ['Order Tax (Min)', 'min']], :sortable => true
  register_field :shop_order_refund, UserSegment::CoreType::NumberType, :field => :refund, :name => 'Order Refund', :display_method => 'sum', :sort_method => 'sum', :display_methods => [['Order Refund (Max)', 'max'], ['Order Refund (Min)', 'min']], :sort_methods => [['Order Refund (Max)', 'max'], ['Order Refund (Min)', 'min']], :sortable => true
  register_field :shop_order_payment_type, Shop::ShopOrderSegmentField::PaymentType, :field => :payment_type, :name => 'Order Payment Type'

  def self.sort_scope(order_by, direction)
    info = UserSegment::FieldHandler.sortable_fields[order_by.to_sym]
    sort_method = info[:sort_method]
    field = info[:field]

    if sort_method
      Shop::ShopOrder.scoped(:select => "end_user_id, #{sort_method}(#{field}) as #{field}_#{sort_method}", :group => :end_user_id, :order => "#{field}_#{sort_method} #{direction}")
    else
      Shop::ShopOrder.scoped(:order => "#{field} #{direction}")
    end
  end

  def self.get_handler_data(ids, fields)
    Shop::ShopOrder.find(:all, :conditions => {:end_user_id => ids}).group_by(&:end_user_id)
  end

  def self.field_output(user, handler_data, field)
    value = UserSegment::FieldType.field_output(user, handler_data, field)
    value = self.number_to_currency(value) if field.to_s =~ /total/
    value
  end
end
