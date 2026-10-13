# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'repository_fixture'
require 'shaka/repository_config'

# A repository can turn the Human comments list off or change its row cap in its Shaka settings.
class HumanCommentsSettingTest < Minitest::Test
  include RepositoryConfigTestHelpers

  def test_the_list_is_on_with_twenty_rows_unless_the_repository_says_otherwise
    with_repository do |root|
      assert_equal [true, 20], Shaka::RepositoryConfig.load(root:).pr_description
                                                      .values_at('show_human_comments', 'max_human_comments')
    end
    with_repository('pr_description' => { 'show_human_comments' => false, 'max_human_comments' => 5 }) do |root|
      assert_equal [false, 5], Shaka::RepositoryConfig.load(root:).pr_description
                                                      .values_at('show_human_comments', 'max_human_comments')
    end
  end

  def test_the_switch_takes_a_boolean_and_the_cap_a_positive_whole_number
    [{ 'show_human_comments' => 'no' }, { 'show_human_comments' => nil }, { 'max_human_comments' => 0 },
     { 'max_human_comments' => '20' }, { 'max_human_comments' => 2.5 }].each do |section|
      with_repository('pr_description' => section) do |root|
        error = assert_raises(Shaka::Error) { Shaka::RepositoryConfig.load(root:) }
        assert_includes error.message, "pr_description.#{section.keys.first}"
      end
    end
  end
end
