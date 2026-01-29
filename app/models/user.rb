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
  validates :display_name, length: { maximum: 50 }, allow_blank: true

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

  # Preferred label for displaying the user in the UI
  def display_label
    display_name.presence || email
  end

  # When true, Devise will not send the "password changed" email (used for admin
  # temporary password resets where the password is shown in the UI instead).
  attr_accessor :skip_password_change_notification

  # Skip password-change email when set by admin reset (avoids SMTP in environments
  # where mail is not configured, e.g. Render without SendGrid).
  def send_password_change_notification
    return if skip_password_change_notification
    super
  end

  # Generate a secure temporary password for admin reset
  def generate_temporary_password
    # Ensure password contains at least one lowercase, uppercase, and digit
    lowercase = ('a'..'z').to_a
    uppercase = ('A'..'Z').to_a
    digits = ('0'..'9').to_a
    all_chars = lowercase + uppercase + digits

    # Start with guaranteed characters from each category
    temp_password = [
      lowercase.sample,
      uppercase.sample,
      digits.sample
    ]

    # Fill remaining 9 characters randomly
    9.times { temp_password << all_chars.sample }

    # Shuffle to randomize position of guaranteed characters
    temp_password = temp_password.shuffle.join

    # Update user with new password
    self.password = temp_password
    self.password_confirmation = temp_password
    save!(validate: false)

    temp_password
  end
end
