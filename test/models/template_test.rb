require "test_helper"

class TemplateTest < ActiveSupport::TestCase
  test "should create template with valid attributes" do
    template = Template.new(
      name: "Test Template",
      description: "A test template",
      category: "post-onboarding",
      is_public: true,
      workflow_data: [{ type: "question", title: "Question 1" }]
    )
    assert template.valid?
    assert template.save
  end

  test "should not create template without name" do
    template = Template.new(
      description: "A test template",
      category: "post-onboarding"
    )
    assert_not template.valid?
    assert_includes template.errors[:name], "can't be blank"
  end

  test "should not create template without category" do
    template = Template.new(
      name: "Test Template",
      description: "A test template"
    )
    assert_not template.valid?
    assert_includes template.errors[:category], "can't be blank"
  end

  test "should store workflow_data as JSON" do
    workflow_data = [
      { type: "question", title: "Question 1" },
      { type: "action", title: "Action 1" }
    ]
    template = Template.create!(
      name: "Test Template",
      category: "test",
      workflow_data: workflow_data
    )

    # JSON stores keys as strings, not symbols
    assert_equal 2, template.workflow_data.length
    assert_equal "question", template.workflow_data.first["type"]
    assert_equal "Action 1", template.workflow_data.last["title"]
  end

  test "search should find templates by name" do
    # Clear existing templates to avoid fixture interference
    Template.destroy_all

    Template.create!(name: "Post-Onboarding Checklist", category: "post-onboarding", workflow_data: [])
    Template.create!(name: "Troubleshooting Guide", category: "troubleshooting", workflow_data: [])

    results = Template.search("Post-Onboarding")
    assert_equal 1, results.count
    assert_equal "Post-Onboarding Checklist", results.first.name
  end

  test "search should find templates by category" do
    # Clear existing templates to avoid fixture interference
    Template.destroy_all

    Template.create!(name: "Template 1", category: "post-onboarding", workflow_data: [])
    Template.create!(name: "Template 2", category: "troubleshooting", workflow_data: [])

    results = Template.search("troubleshooting")
    assert_equal 1, results.count
    assert_equal "Template 2", results.first.name
  end

  test "public_templates scope should return only public templates" do
    # Clear existing templates to avoid fixture interference
    Template.destroy_all

    Template.create!(name: "Public Template", category: "test", is_public: true, workflow_data: [])
    Template.create!(name: "Private Template", category: "test", is_public: false, workflow_data: [])

    public_templates = Template.public_templates
    assert_equal 1, public_templates.count
    assert_equal "Public Template", public_templates.first.name
  end

  test "by_category scope should filter by category" do
    # Clear existing templates to avoid fixture interference
    Template.destroy_all

    Template.create!(name: "Template 1", category: "post-onboarding", workflow_data: [])
    Template.create!(name: "Template 2", category: "troubleshooting", workflow_data: [])
    Template.create!(name: "Template 3", category: "post-onboarding", workflow_data: [])

    results = Template.by_category("post-onboarding")
    assert_equal 2, results.count
    assert results.all? { |t| t.category == "post-onboarding" }
  end
end
