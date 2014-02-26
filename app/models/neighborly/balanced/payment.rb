module Neighborly::Balanced
  class Payment
    def initialize(customer, contribution, attrs = {})
      @customer, @contribution, @attrs = customer, contribution, attrs
    end

    def checkout!
      @debit = @customer.debit(amount: contribution_amount_in_cents,
                               source: @attrs.fetch(:use_card))
    rescue Balanced::PaymentRequired
      @contribution.cancel!
    else
      @contribution.confirm!
    ensure
      @contribution.update_attributes(payment_id:     @debit.try(:id),
                                      payment_method: :balanced,
                                      payment_choice: :creditcard)
    end

    def contribution_amount_in_cents
      (fee_calculator.net_amount * 100).round
    end

    def fee_calculator
      @fee_calculator and return @fee_calculator

      calculator_class = if ActiveRecord::ConnectionAdapters::Column::TRUE_VALUES.include? @attrs[:pay_fee]
                           Creditcard::TransactionAdditionalFeeCalculator
                         else
                           Creditcard::TransactionInclusiveFeeCalculator
                         end

      @fee_calculator = calculator_class.new(@contribution.value)
    end

    def debit
      @debit.try(:sanitize)
    end

    def successful?
      %w(pending succeeded).include? @debit.try(:status)
    end
  end
end
