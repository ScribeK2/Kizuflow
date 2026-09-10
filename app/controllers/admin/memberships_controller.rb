# Direct members of a group, managed from the group's page (spec Q15).
class Admin::MembershipsController < Admin::BaseController
  SEARCH_LIMIT = 10

  before_action :set_group

  # The member search, answered into the group page's turbo-frame.
  def index
    @query = search_query
    @candidates = candidates_for(@query)
  end

  def create
    user = User.find(params[:user_id])
    membership = @group.user_groups.build(user:)

    if membership.save
      respond_with_members notice: "Added #{user.email} to #{@group.name}."
    else
      respond_with_members alert: membership.errors.full_messages.to_sentence
    end
  end

  # No confirm (spec Q15): adding someone back is one search away, and the
  # flash names who was removed.
  def destroy
    membership = @group.user_groups.find(params[:id])
    email = membership.user.email
    membership.destroy!

    respond_with_members notice: "Removed #{email} from #{@group.name}."
  end

  private

  def set_group
    @group = Group.find(params[:group_id])
  end

  def search_query
    params[:q].to_s.strip
  end

  # Accounts that can sign in, match the search and are not already members.
  def candidates_for(query)
    return User.none if query.blank?

    User.search_by(query)
        .where(deactivated_at: nil)
        .where.not(id: @group.user_groups.select(:user_id))
        .order(:email)
        .limit(SEARCH_LIMIT)
  end

  # The members card comes back whole, with the search re-run for the same
  # words, so the search stays open after an Add.
  def respond_with_members(notice: nil, alert: nil)
    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = notice if notice
        flash.now[:alert] = alert if alert
        @query = search_query
        @candidates = candidates_for(@query)
        render "admin/memberships/changed"
      end
      format.html { redirect_to admin_group_path(@group), notice:, alert: }
    end
  end
end
