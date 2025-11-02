class Template < ApplicationRecord
  # Workflow_data stored as JSON - automatically serialized/deserialized
  validates :name, presence: true
  validates :category, presence: true

  scope :public_templates, -> { where(is_public: true) }
  scope :by_category, ->(category) { where(category: category) }

  def self.search(query)
    # Use case-insensitive LIKE for SQLite compatibility
    where("name LIKE ? OR description LIKE ? OR category LIKE ?", 
          "%#{query}%", "%#{query}%", "%#{query}%")
  end
end

