require File.dirname(__FILE__) + "/../../../../../../spec/spec_helper"

describe Shop::ShopOrderSegmentField do
  reset_domain_tables :end_users, :shop_orders, :user_segments, :user_segment_caches

  before do
    DataCache.reset_local_cache
    test_activate_module('shop')
  end

  after do
    SiteModule.destroy_all
  end

  def create_shop_order(user, amount)
    Shop::ShopOrder.create :end_user_id => user.id, :state => 'shipped', :payment_type => 'standard', :total => amount, :subtotal => amount, :tax => 0, :shipping => 0, :ordered_at => Time.now, :shipped_at => Time.now, :refund => 0
  end

  before(:each) do
    @user1 = EndUser.push_target('test1@test.dev')
    @user2 = EndUser.push_target('test2@test.dev')
    @user3 = EndUser.push_target('test3@test.dev')
    create_shop_order(@user1, 30)
    create_shop_order(@user2, 40)
    create_shop_order(@user2, 5)
  end

  it "should only have valid Shop::ShopOrder fields" do
    Shop::ShopOrder.count.should == 3

    obj = Shop::ShopOrderSegmentField.user_segment_fields_handler_info[:domain_model_class].new
    Shop::ShopOrderSegmentField.user_segment_fields.each do |key, value|
      obj.has_attribute?(value[:field]).should be_true
      obj.respond_to?(value[:display_field]).should be_true
    end
  end

  it "has handler_data" do
    Shop::ShopOrderSegmentField.get_handler_data([@user1.id, @user2.id], [:total]).size.should == 2
  end

  it "can output field data" do
    handler_data = Shop::ShopOrderSegmentField.get_handler_data([@user1.id, @user2.id], [:total])
    Shop::ShopOrderSegmentField.field_output(@user2, handler_data, :shop_order_total).should == "$45.00"

    Shop::ShopOrderSegmentField.user_segment_fields.each do |key, value|
      next if value[:search_only]
      Shop::ShopOrderSegmentField.field_output(@user1, handler_data, key)
    end
  end

  it "should be able to sort on sortable fields" do
    ids = [@user1.id, @user2.id]
    seg = UserSegment.create :name => 'Test', :segment_type => 'custom'
    seg.id.should_not be_nil
    seg.add_ids ids

    Shop::ShopOrderSegmentField.user_segment_fields.each do |key, value|
      next unless value[:sortable]
      scope = Shop::ShopOrderSegmentField.sort_scope(key.to_s, 'DESC')
      scope.should_not be_nil

      seg.order_by = key.to_s
      seg.sort_ids(ids).should be_true
      seg.status.should == 'finished'
      seg.end_user_ids.size.should == 2
    end
  end
end
