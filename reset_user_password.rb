# Password Reset Script
# Run this with: rails runner reset_user_password.rb

puts "=== Password Reset Script ==="
puts ""

# Find users
users = User.all
if users.empty?
  puts "No users found in database"
  exit
end

puts "Found #{users.count} user(s):"
users.each do |user|
  puts "  - #{user.email}"
end

puts ""
puts "To reset password for a user, run:"
puts "  rails runner \"user = User.find_by(email: 'your_email@example.com'); user.password = 'new_password'; user.password_confirmation = 'new_password'; user.save!\""
puts ""
puts "Or use the password reset form at: /users/password/new"

