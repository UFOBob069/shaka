# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'claim_helpers'
require_relative 'configuration_layout_fixture'

class ClaimSubdirectoryTest < Minitest::Test
  include ClaimHelpers
  include ConfigurationLayoutFixture

  HEADS = "aaa\trefs/heads/feature/12/fix\n"

  def test_a_subdirectory_reads_the_repository_settings_and_finds_the_collision
    with_repository_subdirectory do |subdirectory|
      stdout, status = capture_cli(['12', '--root', subdirectory], prs: [], branches: HEADS)
      result = JSON.parse(stdout)

      assert_equal 0, status
      assert_equal 'feature/{issue}/{description}', result.fetch('branch_name')
      assert_equal ['feature/12/fix'], result.fetch('branches')
      assert result.fetch('collision')
    end
  end

  private

  def with_repository_subdirectory
    with_new_layout do |root|
      File.write(File.join(root, '.agents/shaka/config.yml'),
                 YAML.dump(config.merge('branches' => { 'name' => 'feature/{issue}/{description}' })))
      system('git', '-C', root, 'init', '--quiet', exception: true)
      FileUtils.mkdir_p(File.join(root, 'sub'))
      yield File.join(root, 'sub')
    end
  end
end
