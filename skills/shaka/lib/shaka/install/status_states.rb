# frozen_string_literal: true

module Shaka
  module Install
    # The install states `install --status` can tell apart offline. IDs match the #683 matrix;
    # rows a later step detects join this table with that step's scenario.
    module StatusStates
      STATES = {
        'none' => ['No Shaka installation found', 'ok'],
        'A1' => ['Default install, one host', 'ok'],
        'A2' => ['Default install, several hosts', 'ok'],
        'A3' => ['Dedicated source checkout in a custom folder', 'ok'],
        'A4' => ['Custom skills folder', 'ok'],
        'A5' => ['Fork, SSH origin, or non-main branch', 'ok'],
        'A6' => ['Towers selected', 'ok'],
        'A8' => ['PR trial', 'ok'],
        'A9' => ['Helper run from an unregistered clone', 'attention'],
        'B1' => ['Manual pull of the registered branch', 'attention'],
        'B2' => ['Local commits in the source checkout', 'attention'],
        'B3' => ['Dirty tree', 'attention'],
        'B4' => ['Branch switched, detached, or untracked', 'attention'],
        'B5' => ['Origin URL changed', 'attention'],
        'B6' => ['Origin rewritten', 'attention'],
        'B7' => ['Update interrupted', 'attention'],
        'B8' => ['Recorded Ruby removed', 'attention'],
        'B9' => ['Link deleted or repointed', 'attention'],
        'B10' => ['Unsafe file modes', 'attention'],
        'B11' => ['Checkout behind its recorded revision', 'attention'],
        'C1' => ['Orphan installation record', 'attention'],
        'C3' => ['Source checkout is a worktree, or hosts worktrees', 'attention'],
        'C5' => ['Hosts pointing at different installs', 'attention'],
        'E1' => ['Source checkout at the old default, the settings path', 'attention']
      }.freeze

      # The first problem in this order is the one to fix first: later checks read state an
      # earlier problem can make misleading, such as a revision on a switched branch. Steps that
      # update use bin/install, not the helper, so they still run when the recorded Ruby is gone.
      # E1 and C3 come early: their fix is a fresh install, which makes the checkout's other problems moot.
      PROBLEMS = %w[B10 C1 E1 C3 B9 C5 B5 B4 B3 B6 B2 B11 B1 B7 B8 A9].freeze
      HEALTHY = %w[A5 A4 A3 A6 A2 A1 A8].freeze

      module_function

      def finding(id, location, detail, command: nil, decision: nil)
        { 'id' => id, 'location' => location, 'detail' => detail, 'next_command' => command,
          'decision' => decision }
      end
    end
  end
end
