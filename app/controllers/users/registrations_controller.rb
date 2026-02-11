class Users::RegistrationsController < Devise::RegistrationsController
  # Override update to handle display_name updates without requiring current_password
  def update
    self.resource = resource_class.to_adapter.get!(send(:"current_#{resource_name}").to_key)

    # Check if only display_name is being updated (no password or email changes)
    update_params = account_update_params
    user_params = params[:user] || {}

    # If only display_name is present and no sensitive fields are being changed
    only_display_name = user_params.key?(:display_name) &&
                        !user_params.key?(:email) &&
                        !user_params.key?(:password) &&
                        !user_params.key?(:password_confirmation) &&
                        !user_params.key?(:current_password)

    if only_display_name
      # Update display_name without requiring current_password
      if resource.update(display_name: update_params[:display_name])
        redirect_to after_update_path_for(resource), notice: "Display name updated successfully."
      else
        render :edit
      end
    elsif update_resource(resource, account_update_params)
      # Use Devise's default update behavior (requires current_password for email/password changes)
      redirect_to after_update_path_for(resource), notice: "Account updated successfully."
    else
      render :edit
    end
  end

  protected

  # Redirect to the account page after updating settings (including password)
  def after_update_path_for(resource)
    edit_user_registration_path
  end

  # Permit parameters for account updates (including password change)
  def account_update_params
    params.require(:user).permit(
      :display_name,
      :email,
      :password,
      :password_confirmation,
      :current_password
    )
  end

  # Existing sign-up redirects
  def after_sign_up_path_for(resource)
    root_path
  end

  def after_inactive_sign_up_path_for(resource)
    root_path
  end
end
