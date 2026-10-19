# frozen_string_literal: true

# Scenarios for working installs: each builds the state in a temporary HOME and says what status reports.
module HealthyInstallScenarios
  private

  def build_none = { from: @root, location: @root, next: 'bin/install' }

  def build_a1 = healthy(default_install)

  def build_a2 = healthy(default_install('--agent', 'codex', '--agent', 'claude'))

  def build_a4 = healthy(default_install('--skills-dir', @skills_dir))

  def build_a6 = healthy(default_install('--with-rct'))

  def build_a3
    git('-C', @root, 'remote', 'set-url', 'origin', InstallScenarioSupport::OFFICIAL)
    run_install(@root, '--directory', @root, '--agent', 'claude')
    healthy(@root)
  end

  def build_a5
    root = clone_to(default_path)
    run_install(root, '--directory', root, '--repository', @remote)
    healthy(root)
  end

  def build_a8
    trial = File.join(@home, '.local/share/shaka/pr-trials')
    FileUtils.mkdir_p(File.join(trial, '123-example'))
    { from: @root, location: trial, next: nil }
  end

  def build_a9
    root = default_install
    second = clone_to(File.join(@directory, 'second clone'))
    { from: second, location: second, next: "#{helper(root)} install --status" }
  end
end

# Scenarios for installs that need a fix: each reaches the state the way a person would.
module BrokenInstallScenarios
  private

  def build_b1 = problem(default_install.tap { |root| pull(root) }, 'install --update')

  def build_b3 = problem(default_install.tap { |root| File.write(File.join(root, 'notes.txt'), 'draft') })

  def build_b4 = problem(default_install.tap { |root| git('-C', root, 'switch', '-q', '--detach') }, 'switch main')

  def build_b5
    problem(default_install.tap { |root| git('-C', root, 'remote', 'set-url', 'origin', @remote) },
            "remote set-url origin #{InstallScenarioSupport::OFFICIAL}")
  end

  def build_b2
    root = default_install
    commit(root, 'local change')
    problem(root)
  end

  def build_b6
    root = default_install
    commit(@root, 'rewritten', amend: true)
    git('-C', @root, 'push', '--force', '-q', 'origin', 'main')
    git('-C', root, 'fetch', '-q', @remote, '+main:refs/remotes/origin/main')
    problem(root)
  end

  def build_b7
    root = default_install
    record = File.join(root, '.git/shaka-install.json')
    data = JSON.parse(File.read(record)).merge('pending_revision' => git('-C', root, 'rev-parse', 'HEAD').strip)
    File.write(record, JSON.generate(data))
    problem(root, 'install --update')
  end

  def build_b8
    root = default_install
    File.write(File.join(root, '.git/shaka-ruby'), "/nonexistent/ruby\n")
    problem(root, 'bin/install')
  end

  def build_b9
    root = default_install
    link = File.join(@home, '.agents/skills/shaka')
    File.unlink(link)
    { from: root, location: link, next: 'bin/install' }
  end

  def build_b11
    root = default_install
    pull(root)
    record = File.join(root, '.git/shaka-install.json')
    head = git('-C', root, 'rev-parse', 'HEAD').strip
    File.write(record, JSON.generate(JSON.parse(File.read(record)).merge('revision' => head)))
    git('-C', root, 'reset', '-q', '--hard', 'HEAD~1')
    problem(root, "merge --ff-only #{head}")
  end

  def build_b10
    root = default_install
    File.chmod(0o775, root)
    problem(root, "chmod go-w #{Shellwords.escape(File.realpath(root))}")
  end

  # The origin incident: two registered checkouts claim one host folder; its links use only one.
  def build_c1
    orphan = default_install
    File.unlink(File.join(@home, '.agents/skills/shaka'))
    run_install(@root, '--directory', @root, '--repository', @remote)
    { from: @root, location: orphan, next: 'mv ' }
  end

  # Development in the source checkout: it hosts a worktree for a feature branch.
  def build_c3
    root = default_install
    git('-C', root, 'worktree', 'add', '-q', File.join(@directory, 'feature'))
    problem(root, nil)
  end

  # A split install: Claude uses one registered checkout and Cursor another.
  def build_c5
    root = default_install('--agent', 'claude')
    run_install(@root, '--directory', @root, '--repository', @remote, '--agent', 'cursor')
    { from: root, location: @home, next: nil }
  end
end
