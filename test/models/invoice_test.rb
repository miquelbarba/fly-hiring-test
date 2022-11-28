require "test_helper"
require 'minitest/autorun'
require 'rspec/mocks/minitest_integration'

class InvoiceTest < ActiveSupport::TestCase
  test 'when stripe sync is successful' do
    invoice_item = invoice_items(:invoice_item_pending)
    invoice = invoice_item.invoice

    invoice.stripe_sync

    assert invoice.successful?
    refute_nil invoice.stripe_id
    assert invoice.stripe_num_retries.zero?
    refute_nil invoice_item.reload.stripe_id
  end

  test 'when the invoice item is already sync' do
    invoice_item = invoice_items(:invoice_item_successful)
    invoice = invoice_item.invoice

    expect(Stripe::Invoice).not_to receive(:create)

    Stripe::Invoice.retrieve_with(id: invoice.id) do
      invoice.stripe_sync
    end

    Stripe::Invoice.clear!
  end

  test 'when there is an exception in invoice sync' do
    invoice_item = invoice_items(:invoice_item_pending)
    invoice = invoice_item.invoice

    Stripe::Invoice.error_with(Stripe::APIError.new('broken api')) do
      invoice.stripe_sync
    end

    assert invoice.pending?
    assert_nil invoice.stripe_id
    assert invoice.stripe_num_retries == 1
    assert invoice.stripe_error == 'broken api'
    assert_nil invoice_item.reload.stripe_id

    Stripe::Invoice.clear!
  end

  test 'when there is an exception in invoice_item sync' do
    invoice_item = invoice_items(:invoice_item_pending)
    invoice = invoice_item.invoice

    Stripe::InvoiceItem.error_with(Stripe::APIError.new('broken api')) do
      invoice.stripe_sync
    end

    assert invoice.pending?
    refute_nil invoice.stripe_id
    assert invoice.stripe_num_retries == 1
    assert_nil invoice.stripe_error
    assert_nil invoice_item.reload.stripe_id
    assert invoice_item.stripe_error == 'broken api'

    Stripe::InvoiceItem.clear!
  end

  test 'when there is a timeout in Stripe' do
    invoice_item = invoice_items(:invoice_item_pending)
    invoice = invoice_item.invoice

    Stripe::Invoice.slow_with(11.seconds) do
      invoice.stripe_sync
    end

    assert invoice.pending?
    assert_nil invoice.stripe_id
    assert invoice.stripe_num_retries == 1
    assert invoice.stripe_error == 'Timeout sync with Stripe'

    Stripe::Invoice.clear!
  end

  test 'when we have consumed all retires' do
    invoice_item = invoice_items(:invoice_item_pending_max_retries)
    invoice = invoice_item.invoice

    Stripe::Invoice.error_with(Stripe::APIError.new('broken api')) do
      invoice.stripe_sync
    end

    assert invoice.error?
    assert_nil invoice.stripe_id
    assert invoice.stripe_num_retries == 5
    assert invoice.stripe_error == 'broken api'

    Stripe::Invoice.clear!
  end

  test '.stripe_sync_invoices' do
    expect(InvoiceSyncJob).to receive(:perform_later).with(invoices(:invoice_pending))
    expect(InvoiceSyncJob).to receive(:perform_later)
                                .with(invoices(:invoice_pending_max_retries))

    Invoice.stripe_sync_invoices
  end

  test '.error_message when error in invoice items' do
    invoice = invoices(:invoice_pending)
    invoice.invoice_items.create!(stripe_error: 'an error',
                                  quantity: 1,
                                  amount_per_unit: 2,
                                  concept: 'test')

    assert_equal 'an error', invoice.error_message
  end

  test '.error_message when error in invoice' do
    invoice = invoices(:invoice_pending)
    invoice.update!(stripe_error: 'a different error')
    invoice.invoice_items.create!(stripe_error: 'an error',
                                  quantity: 1,
                                  amount_per_unit: 2,
                                  concept: 'test')

    assert_equal 'a different error', invoice.error_message
  end

  test '.summarize_by_month' do
    result = Invoice.summarize_by_month

    assert_equal [{ month: '05', total: 12 }.with_indifferent_access,
                  { month: '06', total: 20.5 }.with_indifferent_access,
                  { month: '07', total: 22.5 }.with_indifferent_access],
                 result
  end
end
