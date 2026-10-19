# frozen_string_literal: true

require 'shellwords'
require_relative 'official_install_support'

# Runs the real installer and `install --status` against a fixture remote in a temporary HOME.
module InstallScenarioSupport
  include OfficialInstallSupport

  OFFICIAL = 'https://github.com/shakacode/shaka.git'
  ENVIRONMENT = { 'BASH_ENV' => nil, 'LANG' => 'en_US.UTF-8', 'LC_ALL' => 'en_US.UTF-8' }.freeze

  # A bare remote's HEAD follows init.defaultBranch, which is master on some machines; clones need main.
  def setup
    super
    git('-C', @remote, 'symbolic-ref', 'HEAD', 'refs/heads/main')
  end

  private

  def healthy(root) = { from: root, location: root, next: "#{helper(root)} install --update" }
  def problem(root, step = nil) = { from: root, location: root, next: step }

  # A clean clone of the fixture remote at the default path, registered as the official source.
  def default_install(*)
    root = clone_to(default_path)
    git('-C', root, 'remote', 'set-url', 'origin', OFFICIAL)
    run_install(root, '--directory', root, *)
    root
  end

  def default_path = File.join(@home, '.local/share/shaka/source')

  def clone_to(path)
    git('clone', '-q', @remote, path)
    path
  end

  def run_install(root, *)
    output, process = Open3.capture2e(environment, RbConfig.ruby, File.join(root, 'bin/install'), *)
    assert_predicate process, :success?, output
  end

  def run_status(root, *flags)
    Open3.capture2e(environment, RbConfig.ruby, File.join(root, 'bin/install'), '--status', *flags)
  end

  def status(root)
    output, process = run_status(root, '--json')
    assert_predicate process, :success?, output
    JSON.parse(output)
  end

  def environment = ENVIRONMENT.merge('HOME' => @home)

  def assert_one_next_step(report, expected)
    steps = report.values_at('next_command', 'decision').compact
    assert_equal 1, steps.size, "exactly one next command or decision: #{report.inspect}"
    return assert_nil report['next_command'], 'expected a decision for a person' if expected.nil?

    assert_includes report['next_command'].to_s, expected
    _output, syntax = Open3.capture2e('sh', '-n', '-c', report['next_command'])
    assert_predicate syntax, :success?, "next command is not valid shell: #{report['next_command']}"
  end

  def pull(root)
    commit(root, 'pulled')
    git('-C', root, 'push', '-q', @remote, 'HEAD:main')
    git('-C', root, 'fetch', '-q', @remote, '+main:refs/remotes/origin/main')
  end

  def commit(root, message, amend: false)
    File.write(File.join(root, 'skills/shaka/SKILL.md'), message)
    git('-C', root, 'add', '.')
    git('-C', root, '-c', 'user.name=Test', '-c', 'user.email=test@example.com', 'commit', '-q',
        *('--amend' if amend), '-m', message)
  end

  def helper(root) = Shellwords.escape(File.join(File.realpath(root), 'skills/shaka/scripts/shaka'))

  def canonical(path)
    return File.realpath(path) if File.exist?(path)

    File.join(canonical(File.dirname(path)), File.basename(path))
  end

  def snapshot
    Dir.glob('**/*', File::FNM_DOTMATCH, base: @home).sort.to_h do |entry|
      path = File.join(@home, entry)
      [entry, File.symlink?(path) ? File.readlink(path) : File.lstat(path).then { |stat| [stat.mode, stat.mtime] }]
    end
  end
end
