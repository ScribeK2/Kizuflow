class Admin::GroupsController < ApplicationController
  before_action :ensure_admin!
  before_action :set_group, only: [:show, :edit, :update, :destroy]

  def index
    @groups = Group.roots.includes(:children, :workflows).order(:position, :name)
  end

  def show
    @workflows = @group.workflows.includes(:user).order(created_at: :desc)
  end

  def new
    @group = Group.new
    @group.parent_id = params[:parent_id] if params[:parent_id]
    @available_parents = Group.all.order(:name)
  end

  def create
    @group = Group.new(group_params)
    if @group.save
      redirect_to admin_groups_path, notice: "Group created successfully."
    else
      @available_parents = Group.all.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @available_parents = Group.where.not(id: @group.id).order(:name)
  end

  def update
    if @group.update(group_params)
      redirect_to admin_groups_path, notice: "Group updated successfully."
    else
      @available_parents = Group.where.not(id: @group.id).order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @group.children.any?
      redirect_to admin_groups_path, alert: "Cannot delete group '#{@group.name}' because it has subgroups. Please reassign or delete subgroups first."
      return
    end

    if @group.workflows.any?
      redirect_to admin_groups_path, alert: "Cannot delete group '#{@group.name}' because it contains workflows. Please reassign workflows to another group first."
      return
    end

    group_name = @group.name
    @group.destroy
    redirect_to admin_groups_path, notice: "Group '#{group_name}' deleted successfully."
  end

  private

  def set_group
    @group = Group.find(params[:id])
  end

  def group_params
    params.require(:group).permit(:name, :description, :parent_id, :position)
  end
end
