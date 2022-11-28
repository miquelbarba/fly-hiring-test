require "test_helper"
require 'minitest/autorun'
require 'rspec/mocks/minitest_integration'

class InvoiceItemTest < ActiveSupport::TestCase
  test 'when stripe sync is successful' do
    invoice_item = invoice_items(:invoice_item_pending)

    result = invoice_item.stripe_sync

    assert result
    refute_nil invoice_item.stripe_id.present?
  end

  test 'when the invoice item is already sync' do
    invoice_item = invoice_items(:invoice_item_successful)

    expect(Stripe::InvoiceItem).not_to receive(:create)

    result = Stripe::InvoiceItem.retrieve_with(id: invoice_item.invoice_id) do
      invoice_item.stripe_sync
    end

    assert result
    refute_nil invoice_item.stripe_id

    Stripe::InvoiceItem.clear!
  end

  test 'when there is an exception in sync' do
    invoice_item = invoice_items(:invoice_item_pending)

    result = Stripe::InvoiceItem.error_with(Stripe::APIError.new('broken api')) do
      invoice_item.stripe_sync
    end

    assert !result
    assert_nil invoice_item.stripe_id
    assert invoice_item.stripe_error == 'broken api'

    Stripe::InvoiceItem.clear!
  end
end
