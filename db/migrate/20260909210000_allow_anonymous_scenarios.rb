# A run started from a share link by someone who is not signed in has no user,
# and the schema forced it to name one anyway.
#
# PlayerController#show_shared stamped `user: @workflow.user`, so every anonymous
# run was recorded as the OWNER's. That is not only wrong in the row: it has a
# live consumer in Admin::AnalyticsController#build_agent_stats, which groups by
# users.email — so an editor who shared one workflow widely appeared to be the
# busiest agent in the organisation.
#
# Nullable rather than a designated "Anonymous" user: a sentinel would keep the
# constraint at the cost of a fake account showing up in the admin user list and
# the agent filter, and every reader would still have to know it was special.
# NULL says exactly what is true — nobody we can name ran this.
#
# The readers were audited and need no change: build_agent_stats joins(:user),
# an INNER JOIN, so anonymous runs drop out of per-agent figures on their own;
# the CSV export already writes `scenario.user&.email`; sub-flow children inherit
# the parent's user, so nil propagates correctly; and the `current_user.scenarios`
# lookups are Scenario-mode only, which always has a user.
class AllowAnonymousScenarios < ActiveRecord::Migration[8.1]
  class Scenario < ActiveRecord::Base
  end

  def up
    change_column_null :scenarios, :user_id, true

    # Existing share-link runs carry the owner's id, which we know is wrong and
    # cannot correct: the visitor was never recorded. NULL replaces a known-false
    # value with an honest unknown, and `shared_access` identifies exactly the
    # affected set. Runs created after this change keep a real user when the
    # visitor was signed in, so this only ever applies to the backlog.
    corrected = Scenario.where(shared_access: true).update_all(user_id: nil)
    say "Cleared the owner attribution from #{corrected} existing share-link run(s)"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
