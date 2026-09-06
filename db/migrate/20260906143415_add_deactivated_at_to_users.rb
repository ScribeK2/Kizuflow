class AddDeactivatedAtToUsers < ActiveRecord::Migration[8.1]
  # Administrative deactivation gets its own column rather than reusing Devise's
  # `locked_at`. `locked_at` already means "locked out by failed attempts", and
  # devise.rb sets `unlock_strategy = :both` with `unlock_in = 1.hour` — so
  # deactivating someone through `lock_access!` silently expired after an hour,
  # and a user who mistyped their password five times was indistinguishable from
  # one an admin had deliberately offboarded.
  def change
    add_column :users, :deactivated_at, :datetime
    add_index :users, :deactivated_at
  end
end
