class Template < ApplicationRecord
  # Workflow_data stored as JSON - automatically serialized/deserialized
  validates :name, presence: true
  validates :category, presence: true

  scope :public_templates, -> { where(is_public: true) }
  scope :by_category, ->(category) { where(category: category) }

  def self.search(query)
    # Cross-database case-insensitive search
    # Uses ILIKE for PostgreSQL, LIKE for SQLite
    search_term = "%#{query}%"
    like_op = connection.adapter_name.downcase.include?('postgresql') ? 'ILIKE' : 'LIKE'
    where("name #{like_op} ? OR description #{like_op} ? OR category #{like_op} ?", 
          search_term, search_term, search_term)
  end
end

