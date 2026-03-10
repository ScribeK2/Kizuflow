namespace :descriptions do
  desc "Migrate workflow descriptions from plain text markdown to Action Text"
  task migrate: :environment do
    begin
      require "redcarpet"
    rescue LoadError
      abort "ERROR: redcarpet gem is required for this migration. Add it temporarily: gem 'redcarpet' and bundle install."
    end

    renderer = Redcarpet::Render::HTML.new(hard_wrap: true, link_attributes: { target: "_blank", rel: "noopener" })
    markdown = Redcarpet::Markdown.new(renderer,
      fenced_code_blocks: true, autolink: true, tables: true,
      strikethrough: true, no_intra_emphasis: true)

    workflows = Workflow.where.not(description: [nil, ""])
    puts "Migrating #{workflows.count} workflow descriptions..."

    migrated = 0
    skipped = 0

    workflows.find_each do |workflow|
      # Skip if already has rich text description
      if workflow.rich_text_description&.body.present?
        skipped += 1
        next
      end

      html = markdown.render(workflow.read_attribute(:description))
      workflow.update_column(:description, nil) # Clear plain text
      workflow.update!(description: html)
      migrated += 1
    rescue => e
      puts "  ERROR: Workflow ##{workflow.id} (#{workflow.title}): #{e.message}"
    end

    puts "\nMigration complete:"
    puts "  Migrated: #{migrated}"
    puts "  Skipped (already migrated): #{skipped}"
  end

  desc "Convert HTML descriptions (from Trix/Action Text) to Markdown"
  task convert_html_to_markdown: :environment do
    converted = 0
    skipped = 0

    Workflow.where.not(description: [nil, ""]).find_each do |workflow|
      html = workflow[:description]
      next if html.blank?

      # Skip if it doesn't look like HTML
      unless html.match?(/<[a-z][\s\S]*>/i)
        skipped += 1
        next
      end

      markdown = html_to_markdown(html)
      workflow.update_column(:description, markdown)
      converted += 1
    end

    puts "Converted #{converted} descriptions from HTML to Markdown (#{skipped} already plain text)"
  end

  # Simple Trix-HTML to Markdown converter.
  # Trix only produces: strong, em, del, a, h1, blockquote, pre, code,
  # ul/ol/li, br, and div (as paragraphs).
  def html_to_markdown(html)
    text = html.dup

    # Normalize line endings
    text.gsub!("\r\n", "\n")

    # Block-level elements first (order matters)

    # Headings (Trix uses h1 only)
    text.gsub!(%r{<h1[^>]*>(.*?)</h1>}mi) { "## #{strip_tags(Regexp.last_match(1)).strip}\n\n" }

    # Blockquotes
    text.gsub!(%r{<blockquote[^>]*>(.*?)</blockquote>}mi) do
      inner = strip_tags(Regexp.last_match(1)).strip
      inner.lines.map { |l| "> #{l.strip}" }.join("\n") + "\n\n"
    end

    # Code blocks (pre > code)
    text.gsub!(%r{<pre[^>]*>\s*<code[^>]*>(.*?)</code>\s*</pre>}mi) do
      "```\n#{decode_entities(Regexp.last_match(1)).strip}\n```\n\n"
    end
    text.gsub!(%r{<pre[^>]*>(.*?)</pre>}mi) do
      "```\n#{strip_tags(Regexp.last_match(1)).strip}\n```\n\n"
    end

    # Lists — convert <ul>/<ol> with <li> items
    text.gsub!(%r{<ol[^>]*>(.*?)</ol>}mi) do
      items = Regexp.last_match(1).scan(%r{<li[^>]*>(.*?)</li>}mi).flatten
      items.each_with_index.map { |item, i| "#{i + 1}. #{strip_tags(item).strip}" }.join("\n") + "\n\n"
    end
    text.gsub!(%r{<ul[^>]*>(.*?)</ul>}mi) do
      items = Regexp.last_match(1).scan(%r{<li[^>]*>(.*?)</li>}mi).flatten
      items.map { |item| "- #{strip_tags(item).strip}" }.join("\n") + "\n\n"
    end

    # Inline elements
    text.gsub!(%r{<strong[^>]*>(.*?)</strong>}mi) { "**#{Regexp.last_match(1)}**" }
    text.gsub!(%r{<b[^>]*>(.*?)</b>}mi) { "**#{Regexp.last_match(1)}**" }
    text.gsub!(%r{<em[^>]*>(.*?)</em>}mi) { "_#{Regexp.last_match(1)}_" }
    text.gsub!(%r{<i[^>]*>(.*?)</i>}mi) { "_#{Regexp.last_match(1)}_" }
    text.gsub!(%r{<del[^>]*>(.*?)</del>}mi) { "~~#{Regexp.last_match(1)}~~" }
    text.gsub!(%r{<code[^>]*>(.*?)</code>}mi) { "`#{Regexp.last_match(1)}`" }
    text.gsub!(%r{<a[^>]*href="([^"]*)"[^>]*>(.*?)</a>}mi) { "[#{Regexp.last_match(2)}](#{Regexp.last_match(1)})" }

    # Line breaks and divs (Trix wraps lines in divs)
    text.gsub!(%r{<br\s*/?>}i, "\n")
    text.gsub!(%r{<div[^>]*>}i, "")
    text.gsub!(%r{</div>}i, "\n")

    # Strip any remaining HTML tags
    text.gsub!(/<[^>]+>/, "")

    # Decode HTML entities
    text = decode_entities(text)

    # Clean up excessive blank lines
    text.gsub!(/\n{3,}/, "\n\n")
    text.strip
  end

  def strip_tags(html)
    html.gsub(/<[^>]+>/, "")
  end

  def decode_entities(text)
    text.gsub("&amp;", "&")
        .gsub("&lt;", "<")
        .gsub("&gt;", ">")
        .gsub("&quot;", '"')
        .gsub("&#39;", "'")
        .gsub("&nbsp;", " ")
  end
end
