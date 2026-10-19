# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/update_check'

class UpdateCheckNoticeTest < Minitest::Test
  SOURCE = { 'kind' => 'revision', 'revision' => 'a' * 40,
             'repository' => 'https://github.com/shakacode/shaka.git' }.freeze

  def check(ahead_by, oldest)
    answer = JSON.generate({ 'status' => 'ahead', 'ahead_by' => ahead_by, 'oldest' => oldest })
    Shaka::UpdateCheck.new(source: SOURCE, branch: 'main', registered: true, helper: '/installed/shaka',
                           runner: ->(*) { [answer, '', true] }).result
  end

  def hours_ago(hours) = (Time.now - (hours * 3600)).utc.iso8601

  def test_a_few_new_commits_from_today_wait_and_report_their_count
    result = check(2, hours_ago(3))
    assert_equal 'recent', result.fetch('status')
    assert_equal 2, result.fetch('commits_behind')
    assert_includes result.fetch('guidance'), '2 commits behind official main'
    refute_includes result.fetch('guidance'), 'install --update'
  end

  def test_a_day_old_commit_or_enough_commits_offer_the_update
    assert_equal 'available', check(1, hours_ago(25)).fetch('status')
    assert_equal 'available', check(3, hours_ago(1)).fetch('status')
  end

  def test_a_missing_date_leaves_the_count_in_charge
    [nil, 'yesterday'].each do |oldest|
      assert_equal 'recent', check(2, oldest).fetch('status')
      assert_equal 'available', check(4, oldest).fetch('status')
    end
  end

  def test_an_unusable_count_still_offers_the_update
    [nil, 0, '2'].each { |ahead_by| assert_equal 'available', check(ahead_by, hours_ago(1)).fetch('status') }
  end
end
