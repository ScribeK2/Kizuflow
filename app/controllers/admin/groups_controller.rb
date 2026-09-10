class Admin::GroupsController < Admin::BaseController
  before_action :set_group, only: %i[show edit update destroy]
  before_action :keep_global_locked, only: :edit

  def index
    @nodes = Group.tree_nodes
    @member_counts = Group.member_counts
    @workflow_counts = Group.workflow_counts_including_subgroups
    @parent_ids = @nodes.filter_map(&:parent_id).to_set
  end

  def show
    @workflows = @group.workflows.includes(:user).order(created_at: :desc)
  end

  def new
    @group = Group.new(parent_id: params[:parent_id])
    @parent_options = Group.parent_options_for(@group)
  end

  def edit
    @parent_options = Group.parent_options_for(@group)
  end

  def create
    @group = Group.new(group_params)
    if @group.save
      redirect_to admin_group_path(@group), notice: "Created #{@group.name}."
    else
      @parent_options = Group.parent_options_for(@group)
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @group.update(group_params)
      redirect_to admin_group_path(@group), notice: "Saved #{@group.name}."
    else
      @parent_options = Group.parent_options_for(@group)
      render :edit, status: :unprocessable_content
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
    if @group.destroy
      redirect_to admin_groups_path, notice: "Group '#{group_name}' deleted successfully."
    else
      redirect_to admin_groups_path, alert: @group.errors.full_messages.to_sentence
    end
  end

  private

  def set_group
    @group = Group.find(params[:id])
  end

  # Global's name and place are what everyone relies on (spec Q39). update is
  # refused by Group#global_stays_put; this keeps the form from being offered.
  def keep_global_locked
    return unless @group.global?

    redirect_to admin_group_path(@group), alert: "Global can't be renamed or moved."
  end

  # No position: groups sort by name everywhere (spec Q33). The column stays.
  def group_params
    params.expect(group: %i[name description parent_id])
  end
end
