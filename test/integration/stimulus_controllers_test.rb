require "test_helper"

# Stimulus eager-loads every file in app/javascript/controllers, so a controller
# whose mount is deleted still ships to every page and nothing fails, and a view
# naming a controller that doesn't exist fails just as quietly. By 2026-09-10
# fifteen controllers and a dozen target attributes had drifted into that state.
# This reads the source in both directions; it doesn't run JavaScript.
class StimulusControllersTest < ActiveSupport::TestCase
  CONTROLLER_DIR = Rails.root.join("app/javascript/controllers")
  SOURCE_GLOBS = %w[app/views/**/*.erb app/helpers/**/*.rb app/javascript/**/*.js].freeze
  # A value built at render time (shared/_card's "#{local_assigns[:controller]}")
  # names no controller itself, so `#`, `<` and `$` end the literal; the caller
  # passing `controller: "x"` is what the second alternative reads.
  MOUNT = /data-controller=\\?["']([^"'<$#]*)|controller: ["']([^"'#]*)["']/
  TARGET = /data-([a-z0-9-]+)-target=|\b([a-z0-9_]+)_target:/

  test "every controller file is mounted somewhere other than itself" do
    unmounted = controller_files.reject do |id, file|
      mounts.fetch(id, []).any? { it != file }
    end

    assert_empty unmounted.keys.sort, "controllers nothing mounts: #{unmounted.keys.sort.join(', ')}"
  end

  test "every mounted controller has a file" do
    missing = mounts.keys - controller_files.keys

    assert_empty missing.sort, "mounted but no file: #{missing.sort.join(', ')}"
  end

  test "every target attribute names a controller that has a file" do
    targets = source_files.flat_map { |file| File.read(file).scan(TARGET).map { it[0] || it[1].tr("_", "-") } }.uniq
    missing = targets - controller_files.keys

    assert_empty missing.sort, "targets naming no controller: #{missing.sort.join(', ')}"
  end

  private

  def controller_files
    @controller_files ||= Rails.root.glob("app/javascript/controllers/**/*_controller.js").to_h do |path|
      id = path.relative_path_from(CONTROLLER_DIR).to_s.delete_suffix("_controller.js").tr("_", "-").gsub("/", "--")
      [id, path.to_s]
    end
  end

  def mounts
    @mounts ||= source_files.each_with_object(Hash.new { |h, k| h[k] = [] }) do |file, found|
      File.read(file).scan(MOUNT).each do |attr, kwarg|
        (attr || kwarg).split.each { found[it] << file }
      end
    end
  end

  def source_files
    @source_files ||= SOURCE_GLOBS.flat_map { Rails.root.glob(it) }.map(&:to_s)
  end
end
