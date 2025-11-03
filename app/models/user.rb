class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :workflows, dependent: :destroy

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
end

