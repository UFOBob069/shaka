# frozen_string_literal: true

require_relative 'test_helper'
require 'fileutils'
require 'rbconfig'

# A source checkout holding Shaka and every tower skill, installed through a copied bin/install.
module CompanionTowersSupport
  SKILLS = { 'shaka' => 'shaka source', 'rct' => 'rct source', 'mct' => 'codex mct source',
             'mct-claude' => 'mct source', 'rct-claude' => 'rct-claude source' }.freeze

  def setup
    @directory = Dir.mktmpdir('workflows-companion-towers')
    @installer = File.join(@directory, 'source', 'bin', 'install')
    @skills_dir = File.join(@directory, 'isolated profile', 'skills')
    @home = File.join(@directory, 'home')
    FileUtils.mkdir_p(File.dirname(@installer))
    write_skills
    copy_installer
  end

  def copy_installer
    FileUtils.cp(File.expand_path('../bin/install', __dir__), @installer)
    library = File.join(@directory, 'source', 'skills', 'shaka', 'lib', 'shaka')
    FileUtils.mkdir_p(library)
    FileUtils.cp(File.expand_path('../skills/shaka/lib/shaka/installer.rb', __dir__),
                 File.join(library, 'installer.rb'))
    FileUtils.cp(File.expand_path('../skills/shaka/lib/shaka/ruby_requirement.rb', __dir__), library)
    FileUtils.cp_r(File.expand_path('../skills/shaka/lib/shaka/install', __dir__),
                   File.join(library, 'install'))
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  private

  def assert_linked(name)
    assert File.symlink?(destination(name)), name
    refute_equal File.realpath(source(name)), File.readlink(destination(name))
    assert_includes File.readlink(destination(name)), '/.local/share/shaka/installs/'
    assert_equal SKILLS.fetch(name), File.read(File.join(destination(name), 'SKILL.md'))
  end

  def write_skills
    SKILLS.each do |name, content|
      FileUtils.mkdir_p(source(name))
      File.write(File.join(source(name), 'SKILL.md'), content)
    end
    write_helper
    version_dir = File.join(source('shaka'), 'lib/shaka')
    FileUtils.mkdir_p(version_dir)
    File.write(File.join(version_dir, 'version.rb'), "module Shaka\n  VERSION = '0.1.0.pre.1'\nend\n")
  end

  def write_helper
    helper = File.join(source('shaka'), 'scripts/shaka')
    FileUtils.mkdir_p(File.dirname(helper))
    File.write(helper, "#!/usr/bin/env ruby\n")
    File.chmod(0o755, helper)
  end

  def source(name)
    File.join(@directory, 'source', 'skills', name)
  end

  def destination(name)
    File.join(@skills_dir, name)
  end

  def install(*flags)
    Open3.capture2e({ 'HOME' => @home }, RbConfig.ruby, @installer, '--skills-dir', @skills_dir, *flags)
  end
end
