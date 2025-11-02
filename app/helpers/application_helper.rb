module ApplicationHelper
  # Safely display workflow description (handles both text and rich text)
  def display_workflow_description(workflow)
    if workflow.description.present?
      if workflow.description.respond_to?(:to_plain_text)
        # Action Text rich text
        workflow.description.to_plain_text
      else
        # Plain text fallback
        workflow.description.to_s
      end
    else
      "No description"
    end
  end
  
  # Render rich text content safely
  def render_rich_text(content)
    if content.present?
      if content.respond_to?(:to_s)
        content_tag(:div, content.to_s.html_safe, class: "prose prose-sm max-w-none")
      else
        content.to_s
      end
    end
  end

  # Render glassmorphism card with block content
  def render_card(title: nil, icon: nil, with_3d: false, css_class: nil, controller: nil, content_class: nil, footer: nil, &block)
    content = capture(&block) if block_given?
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
end

