class CreateInvoiceItems < ActiveRecord::Migration[7.0]
  def change
    create_table :invoice_items do |t|
      t.belongs_to :invoice, null: false, foreign_key: true, index: true
      t.string :concept, null: false
      t.integer :quantity, null: false
      t.decimal :amount_per_unit, null: false, precision: 8, scale: 2

      # We store the stripe_id of this item in our database
      t.string :stripe_id
      t.string :stripe_error

      t.timestamps
    end
  end
end
