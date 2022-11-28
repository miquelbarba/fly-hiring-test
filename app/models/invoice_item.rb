
class InvoiceItem < ApplicationRecord
  belongs_to :invoice, optional: false

  validates :concept, presence: true
  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :amount_per_unit, presence: true, numericality: true

  def stripe_sync
    return true if invoice_item_in_stripe?

    stripe_invoice_item = Stripe::InvoiceItem.create(invoice: invoice.id,
                                                     unit_amount_decimal: amount_per_unit,
                                                     quantity: quantity)

    update!(stripe_id: stripe_invoice_item.stripe_id, stripe_error: nil)

    true
  rescue Stripe::StripeError => e
    update!(stripe_error: e.message)

    false
  end

  private

  def invoice_item_in_stripe?
    Stripe::InvoiceItem.retrieve(id)
    true
  rescue Stripe::InvalidRequestError
    false
  end
end
