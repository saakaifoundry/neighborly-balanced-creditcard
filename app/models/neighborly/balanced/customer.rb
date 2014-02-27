module Neighborly::Balanced
  class Customer
    def initialize(user, request_params)
      @user = user
      @request_params = request_params
    end

    def fetch
      current_customer_uri = @user.balanced_contributor.try(:uri)
      @customer          ||= if current_customer_uri
                               ::Balanced::Customer.find(current_customer_uri)
                             else
                               create!
                             end
    end

    def update!
      return unless user_params
      fetch.name    = user_params[:name]
      fetch.address = { line1:         user_params[:address_street],
                         city:         user_params[:address_city],
                         state:        user_params[:address_state],
                         postal_code:  user_params[:address_zip_code]
                       }
      fetch.save

      if ActiveRecord::ConnectionAdapters::Column::TRUE_VALUES.include? user_params.delete(:update_address)
        @user.update!(user_params.reject! {| key, value | key == :name })
      end
    end

    private
    def create!
      customer = ::Balanced::Customer.new(meta:    { user_id: @user.id },
                                          name:    @user.display_name,
                                          email:   @user.email,
                                          address: {
                                            line1:        @user.address_street,
                                            city:         @user.address_city,
                                            state:        @user.address_state,
                                            postal_code:  @user.address_zip_code
                                          })
      customer.save
      @user.create_balanced_contributor(uri: customer.uri)

      customer
    end

    def user_params
      @request_params.permit(payment: [user: %i(
                                             name
                                             address_street
                                             address_city
                                             address_state
                                             address_zip_code
                                             update_address
                                           )])[:payment][:user]
    end
  end
end
