class Admin::UsersController < ApplicationController
  before_action :ensure_admin!

  def index
    @users = User.order(created_at: :desc)
  end

  def update
    @user = User.find(params[:id])
    if @user.update(user_params)
      redirect_to admin_users_path, notice: "User #{@user.email} was successfully updated."
    else
      redirect_to admin_users_path, alert: "Failed to update user: #{@user.errors.full_messages.join(', ')}"
    end
  end

  def update_role
    @user = User.find(params[:id])
    new_role = params[:role]
    
    if User::ROLES.include?(new_role)
      @user.update(role: new_role)
      redirect_to admin_users_path, notice: "User #{@user.email} role updated to #{new_role.capitalize}."
    else
      redirect_to admin_users_path, alert: "Invalid role specified."
    end
  end

  private

  def user_params
    params.require(:user).permit(:role)
  end
end

