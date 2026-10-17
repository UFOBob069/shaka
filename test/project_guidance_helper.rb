# frozen_string_literal: true

require 'shaka/guidance'
require 'shaka/configuration/fingerprint'

# Builds repositories with project guidance and reads it back through `shaka guidance`.
module ProjectGuidanceHelper
  GUIDANCE = { 'pr_evidence' => '.agents/pr-evidence.md', 'merge_readiness' => '.agents/merge-readiness.md' }.freeze

  private

  def guidance(name, root, sha) = Shaka::Guidance.new(name:, root:, ref: sha).call

  def files_fingerprint(root, sha)
    settings = Shaka::Configuration.trusted(root:, ref: sha).to_h
    installation = { 'schema_version' => 1, 'version' => '1', 'source' => { 'kind' => 'uninstalled' } }
    Shaka::Configuration::Fingerprint.build(root:, effective_settings: settings, repository: 'shakacode/shaka',
                                            installation:, trusted_ref: sha).components.fetch('files')
  end

  def write_template(root, text)
    FileUtils.mkdir_p(File.join(root, '.github'))
    File.write(File.join(root, '.github/pull_request_template.md'), text)
  end

  def git_commit(root)
    system('git', '-C', root, 'add', '.', exception: true)
    system('git', '-C', root, '-c', 'user.name=Test', '-c', 'user.email=test@example.com',
           'commit', '-qm', 'change', exception: true)
  end

  def head(root) = Open3.capture2('git', '-C', root, 'rev-parse', 'HEAD').first.strip

  def with_guidance(guidance)
    with_repository('project_guidance' => guidance) do |root|
      write_guidance(root, guidance)
      yield root
    end
  end

  def write_guidance(root, guidance)
    guidance.each do |name, path|
      FileUtils.mkdir_p(File.dirname(File.join(root, path)))
      File.write(File.join(root, path), "Trusted #{name}.")
    end
  end

  def commit(root)
    system('git', '-C', root, 'init', '-q', exception: true)
    system('git', '-C', root, 'add', '.', exception: true)
    system('git', '-C', root, '-c', 'user.name=Test', '-c', 'user.email=test@example.com',
           'commit', '-qm', 'trusted', exception: true)
    Open3.capture2('git', '-C', root, 'rev-parse', 'HEAD').first.strip
  end
end
