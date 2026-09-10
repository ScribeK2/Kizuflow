require "test_helper"

# Fixtures load only where a test names them (test_helper leaves `fixtures :all`
# off), so a fixture file for a table that doesn't exist fails nothing until
# someone names it. templates.yml sat like that with no templates table.
class FixtureTablesTest < ActiveSupport::TestCase
  test "every fixture file names a table the schema has" do
    names = Rails.root.glob("test/fixtures/*.yml").map { File.basename(it, ".yml") }
    missing = names.reject { ActiveRecord::Base.connection.table_exists?(it) }

    assert_empty missing, "fixture files with no table: #{missing.join(', ')}"
  end
end
