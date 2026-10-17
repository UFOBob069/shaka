# frozen_string_literal: true

require_relative 'private_setup_test'

module PrivateSeedFixture
  include PrivateSetupFixture

  def assert_seeded(worktree, ref)
    assert_includes File.read(config_path(worktree)), '# kept for the next task'
    assert_equal "Review carefully.\n", File.read(File.join(worktree, '.agents/shaka/review-prompt.md'))
    assert File.executable?(File.join(worktree, '.agents/shaka/bin/test'))
    assert_equal 'complete', Shaka::Configuration.private_source(root: worktree, ref:).status
  end

  def interrupted_seed_setup(worktree, ref, id, after: nil)
    seed_setup(worktree, ref, id).tap do |setup|
      setup.define_singleton_method(:write_seeded_file) do |path, content|
        super(path, content)
        raise Errno::EIO, path if after.nil? || path.end_with?("/#{after}")
      end
    end
  end

  def with_outside_private_link(worktree)
    Dir.mktmpdir('shaka-outside') do |outside|
      FileUtils.mkdir_p(File.join(worktree, '.agents'))
      File.symlink(outside, File.join(worktree, '.agents/shaka'))
      yield outside
    end
  end

  def with_seed_source
    with_setup do |root, ref|
      setup_private(root, ref)
      note_private_config(root, 'kept for the next task')
      File.write(File.join(root, '.agents/shaka/review-prompt.md'), "Review carefully.\n")
      id = File.basename(recovery(root).inspect_checkout.fetch('recovery'))
      yield root, ref, id
    end
  end

  def with_linked_worktree(root)
    Dir.mktmpdir('shaka-seed') do |parent|
      worktree = File.join(File.realpath(parent), 'next-task')
      git(root, 'worktree', 'add', '--quiet', '-b', 'next-task', worktree)
      yield worktree
    ensure
      git(root, 'worktree', 'remove', '--force', worktree) if worktree && File.directory?(worktree)
    end
  end

  def seed_setup(worktree, ref, id) = Shaka::Seam::PrivateSetup.new(root: worktree, ref:, options: { from: id })
  def seed(worktree, ref, id) = seed_setup(worktree, ref, id).setup
end

class PrivateSeedTest < Minitest::Test
  include PrivateSeedFixture

  def test_new_worktree_starts_with_the_clone_copy_including_edits
    with_seed_source do |root, ref, id|
      with_linked_worktree(root) do |worktree|
        result = seed(worktree, ref, id)
        assert_equal [id, 'complete'], result.values_at('seeded_from', 'status')
        refute_equal result.fetch('recovery'), recovery(root).storage
        assert_seeded(worktree, ref)
      end
    end
  end

  def test_interrupted_seed_resumes
    with_seed_source do |root, ref, id|
      with_linked_worktree(root) do |worktree|
        assert_raises(Shaka::Error) { interrupted_seed_setup(worktree, ref, id).setup }
        assert_equal 'complete', seed(worktree, ref, id).fetch('status')
      end
    end
  end

  def test_seed_interrupted_after_a_custom_file_resumes
    with_seed_source do |root, ref, id|
      with_linked_worktree(root) do |worktree|
        assert_raises(Shaka::Error) { interrupted_seed_setup(worktree, ref, id, after: 'review-prompt.md').setup }
        assert_path_exists File.join(worktree, '.agents/shaka/review-prompt.md')
        assert_equal 'complete', seed(worktree, ref, id).fetch('status')
      end
    end
  end

  def test_symlinked_destination_is_refused_without_writing_outside
    with_seed_source do |root, ref, id|
      with_linked_worktree(root) do |worktree|
        with_outside_private_link(worktree) do |outside|
          assert_raises(Shaka::Error) { seed(worktree, ref, id) }
          assert_empty Dir.children(outside)
        end
      end
    end
  end

  def test_seed_refuses_a_copy_with_a_link_and_names_it
    with_seed_source do |root, ref, _id|
      File.symlink('test', File.join(root, '.agents/shaka/bin/extra'))
      id = File.basename(recovery(root).inspect_checkout.fetch('recovery'))
      with_linked_worktree(root) do |worktree|
        error = assert_raises(Shaka::Error) { seed(worktree, ref, id) }
        assert_includes error.message, 'bin/extra'
        refute_path_exists File.join(worktree, '.agents/shaka')
      end
    end
  end

  def test_seed_refuses_after_team_adoption
    with_seed_source do |root, ref, id|
      with_linked_worktree(root) do |worktree|
        FileUtils.mkdir_p(File.join(worktree, '.agents/shaka'))
        File.write(config_path(worktree), "version: 1\n")
        git(worktree, 'add', '-f', '.agents/shaka/config.yml')
        git(worktree, 'commit', '--quiet', '-m', 'adopt team settings')
        error = assert_raises(Shaka::Error) { seed(worktree, ref, id) }
        assert_includes error.message, 'Tracked Shaka configuration'
      end
    end
  end

  def test_seed_refuses_a_differing_destination
    with_seed_source do |root, ref, id|
      with_linked_worktree(root) do |worktree|
        FileUtils.mkdir_p(File.join(worktree, '.agents/shaka'))
        File.write(File.join(worktree, '.agents/shaka/review-prompt.md'), "Mine.\n")
        assert_raises(Shaka::Error) { seed(worktree, ref, id) }
        assert_equal "Mine.\n", File.read(File.join(worktree, '.agents/shaka/review-prompt.md'))
      end
    end
  end

  def test_seed_refuses_generation_options_and_unknown_copies
    with_seed_source do |root, ref, id|
      with_linked_worktree(root) do |worktree|
        mixed = options.merge(from: id)
        error = assert_raises(Shaka::Error) { Shaka::Seam::PrivateSetup.new(root: worktree, ref:, options: mixed).setup }
        assert_includes error.message, '--from'
        assert_raises(Shaka::Error) { seed(worktree, ref, 'f' * 64) }
        refute_path_exists File.join(worktree, '.agents/shaka')
      end
    end
  end

  def test_cli_seeds_from_a_listed_copy
    with_seed_source do |root, ref, id|
      with_linked_worktree(root) do |worktree|
        output, = capture_io { Shaka::Seam.run(['private', 'list', '--root', worktree]) }
        assert_includes JSON.parse(output).map { |copy| copy.fetch('id') }, id
        output, = capture_io do
          assert_equal 0, Shaka::Seam.run(['private', 'setup', '--root', worktree, '--ref', ref, '--from', id])
        end
        assert_equal 'complete', JSON.parse(output).fetch('status')
      end
    end
  end
end
