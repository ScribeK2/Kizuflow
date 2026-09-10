# Resolves the human-readable placement fields an import file carries — group
# name paths, a folder name, tag names — into records, and applies them.
#
# Resolution is separate from application on purpose: an import must be able to
# ask "is this placement legal for this user?" before it writes anything, so a
# permission failure is a validation error rather than a rollback.
#
# Group names are unique scoped to parent_id (see Group), which is what makes a
# name path unambiguous. Paths arrive either slash-separated ("Support / Tier 2")
# or as an array of segments (["Support", "Tier 2"]) — the second form is the
# escape hatch for group names that themselves contain a slash. A single
# segment that matches exactly one group anywhere in the tree is also accepted,
# because that is the name people write; two groups sharing a name still need
# the path.
class WorkflowPlacement
  class InvalidPlacement < StandardError; end

  PATH_SEPARATOR = "/".freeze

  # Uncategorized became Global in Stage 4a. A file exported before then names
  # it, and filing that workflow into Global would show it to everyone signed
  # in, which "Uncategorized" never meant (spec Q49). So the name is dropped
  # with a warning and the workflow waits, with no audience, for someone to
  # choose one — WorkflowPublisher will not publish it until they do.
  RETIRED_GROUP_NAME = "Uncategorized".freeze

  Result = Data.define(:group_ids, :folder_id, :tag_names, :errors, :warnings) do
    def valid? = errors.empty?
  end

  def initialize(user:, groups: [], folder: nil, tags: [])
    @user = user
    @groups = Array(groups)
    @folder = folder.presence
    @tags = Array(tags)
  end

  def resolve
    @resolve ||= build_result
  end

  # A file silent about a dimension is not making a statement about that
  # dimension: silent means "don't touch this," not "clear it." That applies
  # to groups, folder and tags alike, so each write below is guarded on the
  # placement actually having named something for it.
  #
  # replace_groups! keeps the row of a group the workflow stays in, folder and
  # all, so naming the same primary group keeps its folder by itself. The
  # carry-over below still covers a file that names a group without naming a
  # folder: the old folder_id is written onto the primary row only when the new
  # primary group is the same group that already held it. Folder belongs_to
  # :group, so a folder that belonged to the old primary group is not a valid
  # folder under a different one; when the primary group changes, dropping the
  # folder isn't silence being violated, it's the folder no longer applying.
  def apply!(workflow)
    result = resolve
    raise InvalidPlacement, result.errors.pluck(:message).join(", ") unless result.valid?

    folder_id = result.folder_id || carried_over_folder_id(workflow, result.group_ids)

    workflow.replace_groups!(result.group_ids) if result.group_ids.present?
    if folder_id
      workflow.group_workflows.find_by(is_primary: true)&.update!(folder_id: folder_id)
    end
    if result.tag_names.present?
      workflow.tags = result.tag_names.map { |name| find_or_create_tag(name) }
    end
    workflow
  end

  private

  def build_result
    errors = []
    warnings = []
    group_ids = []

    @groups.each_with_index do |path, index|
      group = find_group(path)

      if group.nil? && retired_group?(path)
        warnings << finding("groups[#{index}]", "retired_group", path,
                            "\"Uncategorized\" is no longer a group, so this workflow arrives without it. " \
                            "Choose who can see it before publishing.")
        next
      end

      if group.nil?
        errors << finding("groups[#{index}]", "unknown_group", path,
                          "No group exists at path #{display(path)}.")
        next
      end

      unless permitted?(group)
        errors << finding("groups[#{index}]", "group_not_permitted", path,
                          "You do not have access to the group #{display(path)}.")
        next
      end

      group_ids << group.id
    end

    Result.new(
      group_ids: group_ids.uniq,
      folder_id: resolve_folder_id(group_ids.first, errors),
      tag_names: normalized_tag_names,
      errors:,
      warnings:
    )
  end

  # See the note on apply! — this is the "silence about folder" carry-over,
  # scoped to the case where the placement's new primary group is the same
  # group the workflow's current primary folder already belongs to.
  def carried_over_folder_id(workflow, group_ids)
    return nil if group_ids.blank?

    current_primary = workflow.group_workflows.find_by(is_primary: true)
    return nil unless current_primary&.group_id == group_ids.first

    current_primary.folder_id
  end

  # Walks the path one segment at a time from the root. Group#name is unique
  # per parent_id, so each step of the walk has at most one answer.
  #
  # A single segment that does not name a root is tried as a unique name
  # anywhere in the tree: "Tier 2" under "Support" has no root named that, and
  # requiring the full path made every nested group look missing. Two groups
  # with the same name stay unknown — the path is what disambiguates them.
  def find_group(path)
    segs = segments(path).map { |name| name.to_s.strip }.compact_blank
    return nil if segs.empty?

    walked = walk_from_root(segs)
    return walked if walked
    return nil unless segs.one?

    matches = Group.where(name: segs.first).to_a
    matches.one? ? matches.first : nil
  end

  # Only a lone segment: a path through a real group that happens to hold an
  # "Uncategorized" child is an ordinary unknown path, not the retired group.
  def retired_group?(path)
    segs = segments(path).map { |name| name.to_s.strip }.compact_blank
    segs.one? && segs.first.casecmp?(RETIRED_GROUP_NAME)
  end

  def walk_from_root(segs)
    segs.reduce(nil) do |parent, name|
      match = Group.find_by(name: name, parent_id: parent&.id)
      return nil if match.nil?

      match
    end
  end

  def segments(path)
    return path.map(&:to_s) if path.is_a?(Array)

    path.to_s.split(PATH_SEPARATOR)
  end

  def display(path)
    path.is_a?(Array) ? path.join(" #{PATH_SEPARATOR} ") : path.to_s
  end

  def permitted?(group)
    return true if @user&.admin?

    group.can_be_viewed_by?(@user)
  end

  def resolve_folder_id(primary_group_id, errors)
    return nil if @folder.blank?

    if primary_group_id.nil?
      errors << finding("folder", "unknown_folder", @folder,
                        "A folder needs a group: name a group before naming a folder.")
      return nil
    end

    folder = Folder.find_by(name: @folder, group_id: primary_group_id)

    if folder.nil?
      errors << finding("folder", "unknown_folder", @folder,
                        "No folder named #{@folder} exists in the primary group.")
      return nil
    end

    folder.id
  end

  # Tag validates uniqueness case-insensitively, but find_or_create_by! queries
  # with an exact match — so importing "billing" into an install that already has
  # "Billing" misses the find and then raises on the create, inside the import
  # transaction, as a cryptic failure. Match the way the validation matches.
  def find_or_create_tag(name)
    Tag.where("LOWER(name) = ?", name.downcase).first || Tag.create!(name:)
  end

  def normalized_tag_names
    @tags.map { |name| name.to_s.strip }.compact_blank.uniq(&:downcase)
  end

  # An error or a warning; both carry the same shape so a report can show either.
  def finding(path, code, value, message)
    { path:, code:, message:, value: }
  end
end
