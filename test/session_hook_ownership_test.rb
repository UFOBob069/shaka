# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/install/session_hook'

# The installer may remove only the exact hook it writes, never a user's own entry.
class SessionHookOwnershipTest < Minitest::Test
  def test_user_hooks_that_only_mention_a_helper_are_not_shaka_hooks
    helper = '/opt/skills/shaka/scripts/shaka'
    start = 'update-check --session-start'
    ["echo #{helper} #{start}", "#{helper} update-check", "#{helper} #{start} -v", "shaka #{start}", "#{helper} doctor"]
      .each { |command| refute Shaka::Install::SessionHook.owned?('command' => command), command }
    assert Shaka::Install::SessionHook.owned?('command' => "/a\\ b/skills/shaka/scripts/shaka #{start}")
  end
end
