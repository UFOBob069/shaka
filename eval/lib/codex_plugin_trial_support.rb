# frozen_string_literal: true

require_relative '../../skills/shaka/lib/shaka/install/tree'
require_relative '../../skills/shaka/lib/shaka/doctor/bounded_command'

# Disposable package and command setup shared by the host probes.
module CodexPluginTrialSupport
  ROOT = File.expand_path('../..', __dir__)
  SOURCE = 'https://example.invalid/shaka-plugin-trial.git'

  def prepare(directory)
    @market = File.join(directory, 'market')
    @plugin = File.join(@market, 'plugins/shaka')
    @profile = File.join(directory, 'profile')
    FileUtils.mkdir_p([@plugin, @profile])
    @env = { 'CODEX_HOME' => @profile, 'GIT_CONFIG_GLOBAL' => File.join(directory, 'gitconfig'),
             'SHAKA_CALL_LOG' => 'off', 'SHAKA_RUBY' => nil }
    prepare_marketplace
  end

  def prepare_marketplace
    @report = { 'codex' => capture('codex', '--version').strip, 'ruby' => RUBY_VERSION,
                'source_revision' => capture('git', '-C', ROOT, 'rev-parse', 'HEAD').strip,
                'transport' => 'Git marketplace; HTTPS URL rewritten to disposable local Git repository' }
    build_package
    write_marketplace
    capture('git', '-C', @market, 'init', '--initial-branch=main')
    commit('Initial trial package')
    capture('git', 'config', '--file', @env.fetch('GIT_CONFIG_GLOBAL'),
            "url.file://#{@market}.insteadOf", SOURCE)
  end

  def build_package
    Shaka::Install::Tree.new(['shaka']).copy(ROOT, @plugin)
    # Reuse the existing distribution inventory for guides and installer dependencies.
    distribution_files.each do |path|
      copy_file(File.join(ROOT, path), File.join(@plugin, path))
    end
    copy_manifest
  end

  def distribution_files
    Dir.chdir(ROOT) { Gem::Specification.load('shaka.gemspec').files.grep_v(%r{\Askills/}) }
  end

  def copy_manifest
    fixture = File.join(ROOT, 'eval/fixtures/codex_plugin')
    copy_file(File.join(fixture, 'plugin.json'), File.join(@plugin, 'plugin.json'))
    copy_file(File.join(fixture, 'icon.svg'), File.join(@plugin, 'assets/icon.svg'))
  end

  def copy_file(source, target)
    FileUtils.mkdir_p(File.dirname(target))
    FileUtils.cp(source, target)
  end

  def write_marketplace
    path = File.join(@market, '.agents/plugins/marketplace.json')
    FileUtils.mkdir_p(File.dirname(path))
    content = { name: 'shaka-trial', plugins: [{ name: 'shaka', source: { source: 'local', path: './plugins/shaka' },
                                                 policy: { installation: 'AVAILABLE', authentication: 'ON_USE' },
                                                 category: 'Developer Tools' }] }
    File.write(path, JSON.pretty_generate(content))
  end

  def commit(message)
    capture('git', '-C', @market, 'add', '.')
    capture('git', '-C', @market, '-c', 'user.name=Trial', '-c', 'user.email=trial@example.invalid',
            'commit', '-qm', message)
  end

  def execute(*command, extra: {})
    Shaka::Doctor::BoundedCommand.new(timeout: 30).call([@env.merge(extra), *command], @market)
  end

  def capture(*command, extra: {})
    output, error, status = execute(*command, extra: extra)
    raise "#{command.first(3).join(' ')} failed: #{error}" unless status

    output
  end

  def json(*) = JSON.parse(capture(*))
end
