module ApplicationHelper
  # Safely display workflow description as plain text
  def display_workflow_description(workflow)
    workflow.description.present? ? workflow.description.to_s : "No description"
  end

  # Temporary: simple HTML sanitizer replacing the old Redcarpet-based markdown renderer.
  # Will be removed when all callers are migrated to Action Text (Tasks 17-19).
  def render_step_markdown(text)
    return "".html_safe if text.blank?

    html = simple_text_to_html(text.to_s)
    safe_html = sanitize(html,
                         tags: %w[p br strong em b i ul ol li h1 h2 h3 h4 h5 h6 a code pre table thead tbody tr th td hr blockquote del],
                         attributes: %w[href target rel])
    content_tag(:div, safe_html, class: "prose prose-sm dark:prose-invert max-w-none")
  end

  # Render glassmorphism card with block content
  def render_card(title: nil, icon: nil, with_3d: false, css_class: nil, controller: nil, content_class: nil, footer: nil, &)
    content = capture(&) if block_given?
    render partial: "shared/card", locals: {
      title: title,
      icon: icon,
      with_3d: with_3d,
      class: css_class,
      controller: controller,
      content_class: content_class,
      footer: footer,
      content: content
    }
  end

  # Build hierarchical group tree structure for dropdown
  def build_group_tree(groups)
    roots = groups.select { |g| g.parent_id.nil? }
    build_tree_nodes(roots, groups)
  end

  # Render a pill badge indicating workflow draft/published status
  def workflow_status_badge(workflow)
    if workflow.draft?
      content_tag(:span, "Draft",
                  class: "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400",
                  aria: { label: "Draft workflow" })
    else
      content_tag(:span, "Published",
                  class: "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-400",
                  aria: { label: "Published workflow" })
    end
  end

  private

  # Minimal text-to-HTML: wraps plain text paragraphs in <p> tags.
  # Temporary bridge until all callers use Action Text.
  def simple_text_to_html(text)
    return text if text.match?(/<[a-z][\s\S]*>/i) # Already HTML
    text.split(/\n{2,}/).map { |para| "<p>#{ERB::Util.html_escape(para.strip)}</p>" }.join
  end

  def build_tree_nodes(parents, all_groups)
    parents.map do |parent|
      children = all_groups.select { |g| g.parent_id == parent.id }
      {
        group: parent,
        children: build_tree_nodes(children, all_groups)
      }
    end
  end
end
