class Admin::UsersController < ApplicationController
  before_action :ensure_admin!

  def index
    @users = User.order(created_at: :desc)
    @all_groups = Group.order(:name)
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

  def update_groups
    @user = User.find(params[:id])
    group_ids = params[:group_ids] || []
    
    # Remove all existing group assignments
    @user.user_groups.destroy_all
    
    # Add new group assignments
    group_ids.each do |group_id|
      next if group_id.blank?
      @user.user_groups.create!(group_id: group_id)
    end
    
    redirect_to admin_users_path, notice: "Groups updated for #{@user.email}."
  end

  def bulk_assign_groups
    user_ids = params[:user_ids] || []
    group_ids = params[:group_ids] || []
    
    if user_ids.empty?
      redirect_to admin_users_path, alert: "No users selected."
      return
    end
    
    users = User.where(id: user_ids)
    users.each do |user|
      # Remove all existing group assignments
      user.user_groups.destroy_all
      
      # Add new group assignments
      group_ids.each do |group_id|
        next if group_id.blank?
        user.user_groups.create!(group_id: group_id)
      end
    end
    
    redirect_to admin_users_path, notice: "Groups assigned to #{users.count} user(s)."
  end

  private

  def user_params
    params.require(:user).permit(:role)
  end
end

