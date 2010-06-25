require File.dirname(__FILE__) + "/../../../../../../spec/spec_helper"

describe Shop::ShopOrderItemSegmentField do
  reset_domain_tables :end_users, :shop_order_items, :user_segments, :user_segment_caches

  before do
    DataCache.reset_local_cache
    test_activate_module('shop')
  end

  after do
    SiteModule.destroy_all
  end

  def create_shop_order_item(user, subtotal, quantity, item_name, order_item_type, order_item_id)
    Shop::ShopOrderItem.create :end_user_id => user.id, :subtotal => (subtotal*quantity), :quantity => quantity, :item_name => item_name, :shop_order_id => 1, :order_item_type => order_item_type, :order_item_id => order_item_id, :currency => "USD", :unit_price => subtotal, :processed => true, :shipped => true
  end

  before(:each) do
    @user1 = EndUser.push_target('test1@test.dev')
    @user2 = EndUser.push_target('test2@test.dev')
    @user3 = EndUser.push_target('test3@test.dev')
    create_shop_order_item(@user1, 30, 2, 'Puzzles', 'Shop::ShopProduct', 1)
    create_shop_order_item(@user2, 40, 1, 'Board Games', 'Shop::ShopProduct', 2)
    create_shop_order_item(@user2, 5, 10, 'Bread Sticks', 'Shop::ShopProduct', 6)
  end

  it "should only have valid Shop::ShopOrderItem fields" do
    Shop::ShopOrderItem.count.should == 3

    obj = Shop::ShopOrderItemSegmentField.user_segment_fields_handler_info[:domain_model_class].new
    Shop::ShopOrderItemSegmentField.user_segment_fields.each do |key, value|
      if value[:field].is_a?(Array)
        value[:field].each { |f| obj.has_attribute?(f).should be_true }
      else
        obj.has_attribute?(value[:field]).should be_true
      end
      obj.respond_to?(value[:display_field]).should be_true
    end
  end

  it "has handler_data" do
    Shop::ShopOrderItemSegmentField.get_handler_data([@user1.id, @user2.id], [:total]).size.should == 2
  end

  it "can output field data" do
    handler_data = Shop::ShopOrderItemSegmentField.get_handler_data([@user1.id, @user2.id], [:subtotal])
#    Shop::ShopOrderItemSegmentField.field_output(@user2, handler_data, :shop_order_total).should == "$45.00"

    Shop::ShopOrderItemSegmentField.user_segment_fields.each do |key, value|
      next if value[:search_only]
      Shop::ShopOrderItemSegmentField.field_output(@user1, handler_data, key)
    end
  end

  it "should be able to sort on sortable fields" do
    ids = [@user1.id, @user2.id]
    seg = UserSegment.create :name => 'Test', :segment_type => 'custom'
    seg.id.should_not be_nil
    seg.add_ids ids

    Shop::ShopOrderItemSegmentField.user_segment_fields.each do |key, value|
      next unless value[:sortable]
      scope = Shop::ShopOrderItemSegmentField.sort_scope(key.to_s, 'DESC')
      scope.should_not be_nil

      seg.order_by = key.to_s
      seg.sort_ids(ids).should be_true
      seg.status.should == 'finished'
      seg.end_user_ids.size.should == 2
    end
  end
end
