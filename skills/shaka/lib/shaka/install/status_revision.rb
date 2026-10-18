# frozen_string_literal: true

module Shaka
  module Install
    # Compares a checkout's HEAD with its recorded revision and the last-fetched origin branch.
    module StatusRevision
      private

      def revision
        head = value('rev-parse', 'HEAD')
        return if head.nil? || head == @record['pending_revision']
        return untracked unless value('rev-parse', '--verify', '--quiet', tracking)
        return rewritten unless ancestor?(recorded, tracking)

        moved(head) unless head == recorded
      end

      def moved(head)
        return pulled(head) if ancestor?(recorded, head) && ancestor?(head, tracking)
        return behind(head) if ancestor?(head, recorded)

        local_commits(head)
      end

      def local_commits(head)
        finding('B2', "checkout #{head[0, 7]} has commits that #{tracking_name} lacks (recorded #{recorded[0, 7]})",
                decision: "Keep these commits in a development checkout, then return #{@record['branch']} " \
                          "to #{recorded[0, 7]}.")
      end

      def behind(head)
        finding('B11', "checkout #{head[0, 7]} is behind its recorded revision #{recorded[0, 7]}",
                command: "#{git_command} merge --ff-only #{recorded}")
      end

      def rewritten
        finding('B6', "#{tracking_name} no longer contains the recorded revision #{recorded[0, 7]}; " \
                      'offline status sees this only after a fetch',
                decision: "Origin history was rewritten; decide which revision #{@record['branch']} should use.")
      end

      def untracked
        finding('B4', "#{tracking_name} is missing from the checkout, so its revision cannot be compared",
                command: "#{git_command} fetch origin #{command(@record['branch'])}")
      end

      def pulled(head)
        finding('B1', "checkout #{head[0, 7]} is a pull of #{tracking_name} past the recorded #{recorded[0, 7]}",
                command: "#{installer} --update")
      end

      def recorded = @record['revision']
      def tracking = "refs/remotes/origin/#{@record['branch']}"
      def tracking_name = "origin/#{@record['branch']}"
    end
  end
end
