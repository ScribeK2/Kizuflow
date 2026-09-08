module Dashboard
  class DataLoader
    attr_reader :user

    def initialize(user)
      @user = user
    end

    def csr?
      !user.can_create_workflows?
    end

    # -- Shared --

    def workflows
      @workflows ||= if user.can_create_workflows?
                       visible_ids = Workflow.visible_to(user).select(:id)
                       draft_ids = Workflow.drafts_visible_to(user).select(:id)
                       Workflow.where(id: visible_ids).or(Workflow.where(id: draft_ids))
                               .includes(:tags).order(created_at: :desc).limit(5)
                     else
                       Workflow.visible_to(user).includes(:tags).recent.limit(5)
                     end
    end

    def recent_scenarios
      @recent_scenarios ||= user_scenarios.includes(:workflow)
                                          .order(created_at: :desc)
                                          .limit(5)
    end

    # -- CSR-specific --

    def pinned_workflow_ids
      @pinned_workflow_ids ||= user.user_workflow_pins.pluck(:workflow_id).to_set
    end

    def pinned_workflows
      @pinned_workflows ||= user.pinned_workflows
                                .where(id: Workflow.visible_to(user).select(:id))
                                .includes(:tags, :steps)
                                .limit(UserWorkflowPin::MAX_PINS)
    end

    # Aggregate per-pinned-workflow run stats for the CSR launcher cards.
    # Returns { workflow_id => { runs:, last_run_at: } }, two queries total.
    def pinned_workflow_stats
      return @pinned_workflow_stats if defined?(@pinned_workflow_stats)

      ids = pinned_workflows.map(&:id)
      return (@pinned_workflow_stats = {}) if ids.empty?

      counts = live_scenarios.where(workflow_id: ids).group(:workflow_id).count
      last_runs = live_scenarios.where(workflow_id: ids).group(:workflow_id).maximum(:created_at)
      @pinned_workflow_stats = ids.index_with { |id| { runs: counts[id].to_i, last_run_at: last_runs[id] } }
    end

    # Distinct workflows the user has run, ordered by most-recent run.
    # Returns up to 5 Scenarios (the most recent live Scenario per workflow),
    # so views can show status and a re-run action without extra queries.
    # Bounded scan keeps this portable across SQLite (test) and Postgres (prod).
    RECENTLY_RUN_LIMIT = 5
    RECENTLY_RUN_SCAN = 100

    def recently_run_workflows
      @recently_run_workflows ||= begin
        seen = {}
        live_scenarios.includes(workflow: :tags)
                      .order(created_at: :desc)
                      .limit(RECENTLY_RUN_SCAN)
                      .each do |sc|
          next if sc.workflow.nil? || seen.key?(sc.workflow_id)

          seen[sc.workflow_id] = sc
          break if seen.size >= RECENTLY_RUN_LIMIT
        end
        seen.values
      end
    end

    def scenarios_this_week
      @scenarios_this_week ||= live_scenarios
                               .where(created_at: Time.current.beginning_of_week..)
                               .count
    end

    def personal_scenario_total
      @personal_scenario_total ||= live_scenarios.count
    end

    def personal_completion_rate
      total = live_scenarios.count
      return 0 if total.zero?

      completed = live_scenarios.where(status: "completed").count
      ((completed * 100.0) / total).round
    end

    def most_used_workflow
      @most_used_workflow ||= begin
        result = live_scenarios.group(:workflow_id)
                               .order(Arel.sql("COUNT(*) DESC"))
                               .limit(1)
                               .pick(:workflow_id, Arel.sql("COUNT(*)"))
        if result&.first
          { workflow: Workflow.find_by(id: result.first), count: result.last }
        end
      end
    end

    # -- SME-specific (company-wide) --

    # Published workflows this viewer can see. Named for what it counts: the old
    # `workflow_count` read like a total, and the view then tried to recover a
    # published figure by subtracting drafts from it — but `visible_to` starts
    # from the `published` scope, so there were never any drafts in it to
    # subtract. An admin owning 11 drafts was shown "10 published" against 21.
    def published_workflow_count
      @published_workflow_count ||= Workflow.visible_to(user).count
    end
    alias workflow_count published_workflow_count

    # Drafts this viewer is allowed to see: org-wide for an admin, their own for
    # an editor, none for anyone else. See Workflow.drafts_visible_to.
    def draft_count
      @draft_count ||= Workflow.drafts_visible_to(user).count
    end

    # The SME dashboard's numbers all obey one boundary: the workflows this
    # viewer can open. For an admin that is the whole library, so their figures
    # are unchanged.
    #
    # These were `company_*` and were unconditional `Scenario.*` calls. "The
    # company" is not a scope the app has anywhere else, and an editor with no
    # group assignments was shown "Published Workflows 0" beside "Total
    # Scenarios 116" — then, once the activity feed became org-wide to fix the
    # admin's empty-feed contradiction, a list naming five workflows they had no
    # access to. Renamed as well as rescoped, because `company_` was what made
    # the unscoped query look deliberate.
    #
    # `recent_scenarios` and `scenario_active` keep their personal scope: the CSR
    # dashboard uses them, and there "your runs" is the whole point.
    def visible_scenarios
      @visible_scenarios ||= Scenario.where(workflow_id: accessible_workflow_ids)
    end

    def visible_scenario_total
      @visible_scenario_total ||= visible_scenarios.count
    end

    def visible_completion_rate
      total = visible_scenario_total
      return 0 if total.zero?

      completed = visible_scenarios.where(status: "completed").count
      ((completed * 100.0) / total).round
    end

    def visible_scenarios_this_week
      @visible_scenarios_this_week ||= visible_scenarios
                                       .where(created_at: Time.current.beginning_of_week..)
                                       .count
    end

    def visible_recent_scenarios
      @visible_recent_scenarios ||= visible_scenarios.includes(:workflow)
                                                     .order(created_at: :desc)
                                                     .limit(5)
    end

    def visible_scenario_active
      @visible_scenario_active ||= visible_scenarios.where(status: "active").count
    end

    def scenario_active
      @scenario_active ||= user_scenarios.where(status: "active").count
    end

    private

    # Every workflow this viewer can reach: the published ones they may see plus
    # the drafts they may see. For an admin, the whole library.
    def accessible_workflow_ids
      @accessible_workflow_ids ||= Workflow.where(id: Workflow.visible_to(user).select(:id))
                                           .or(Workflow.where(id: Workflow.drafts_visible_to(user).select(:id)))
                                           .select(:id)
    end

    def user_scenarios
      @user_scenarios ||= Scenario.where(user: user)
    end

    def live_scenarios
      @live_scenarios ||= user_scenarios.where(purpose: "live")
    end
  end
end
