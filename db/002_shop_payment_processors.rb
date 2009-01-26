class ShopPaymentProcessors < ActiveRecord::Migration
  def self.up

    create_table :shop_payment_processors, :force => true do |t|
      t.string :name
      t.string :currency
      t.string :payment_type
      t.string :processor_handler
      t.text  :options
    end

  end

  def self.down
    drop_table :shop_payment_processors
  end

end
