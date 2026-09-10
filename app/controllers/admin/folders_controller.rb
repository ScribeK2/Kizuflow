# A group's folders, managed from the group's page (spec Q36). There are no
# folder pages: every action answers with the Folders card and a flash, or
# returns to the group page when Turbo isn't there.
class Admin::FoldersController < Admin::BaseController
  before_action :set_group
  before_action :set_folder, only: %i[update destroy]

  def create
    folder = @group.folders.build(folder_params.merge(position: next_position))

    if folder.save
      respond_with_folders notice: "Added the folder #{folder.name}."
    else
      respond_with_folders alert: folder.errors.full_messages.to_sentence
    end
  end

  def update
    old_name = @folder.name

    if @folder.update(folder_params)
      respond_with_folders notice: "Renamed #{old_name} to #{@folder.name}."
    else
      respond_with_folders alert: @folder.errors.full_messages.to_sentence
    end
  end

  def destroy
    name = @folder.name
    @folder.destroy
    respond_with_folders notice: "Deleted the folder #{name}. Its workflows are now unfiled."
  end

  def reorder
    folder_ids = params[:folder_ids]
    return head :bad_request unless folder_ids.is_a?(Array)

    Folder.transaction do
      folder_ids.each_with_index do |id, index|
        @group.folders.where(id: id).update_all(position: index)
      end
    end

    head :ok
  end

  private

  def set_group
    @group = Group.find(params[:group_id])
  end

  def set_folder
    @folder = @group.folders.find(params[:id])
  end

  # Name only: descriptions stay in the table but are no longer edited (Q36).
  def folder_params
    params.expect(folder: [:name])
  end

  # A new folder goes to the bottom, beside the Add form it came from.
  def next_position
    (@group.folders.maximum(:position) || -1) + 1
  end

  def respond_with_folders(notice: nil, alert: nil)
    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = notice if notice
        flash.now[:alert] = alert if alert
        render "admin/folders/changed"
      end
      format.html { redirect_to admin_group_path(@group), notice:, alert: }
    end
  end
end
