class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :workflows, dependent: :destroy
  has_many :user_groups, dependent: :destroy
  has_many :groups, through: :user_groups

  # Role constants
  ROLES = %w[admin editor user].freeze

  # Validations
  validates :role, presence: true, inclusion: { in: ROLES }

  # Scopes
  scope :admins, -> { where(role: 'admin') }
  scope :editors, -> { where(role: 'editor') }
  scope :users, -> { where(role: 'user') }

  # Role checking methods
  def admin?
    role == 'admin'
  end

  def editor?
    role == 'editor'
  end

  def user?
    role == 'user'
  end

  # Check if user can create workflows
  def can_create_workflows?
    admin? || editor?
  end

  # Check if user can edit workflows
  def can_edit_workflows?
    admin? || editor?
  end

  # Check if user can manage templates
  def can_manage_templates?
    admin?
  end

  # Check if user can access admin panel
  def can_access_admin?
    admin?
  end

  # Get groups accessible to this user (admins see all, others see assigned groups)
  def accessible_groups
    admin? ? Group.all : groups
  end

  # Generate a secure temporary password for admin reset
  def generate_temporary_password
    # Generate 12-character secure password using only safe characters
    chars = ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a
    temp_password = Array.new(12) { chars.sample }.join

    # Update user with new password
    self.password = temp_password
    self.password_confirmation = temp_password
    save!(validate: false)

    temp_password
  end
end
