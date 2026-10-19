# frozen_string_literal: true

require 'ripper'
require_relative 'install_support'
require_relative '../skills/shaka/lib/shaka/install/direct_source'
require_relative '../skills/shaka/lib/shaka/install/tree'

# Installer output uses one vocabulary, and refusals the fixture cannot reach still name a next step.
class InstallRefusalWordingTest < Minitest::Test
  include InstallTestSupport

  RETIRED = /retained copy|official main|\bupstream\b/i
  SOURCES = ['bin/install', 'skills/shaka/lib/shaka/installer.rb', 'skills/shaka/scripts/shaka',
             *Dir.glob('skills/shaka/lib/shaka/install/*.rb', base: File.expand_path('..', __dir__))].freeze

  def test_installer_output_avoids_retired_words
    SOURCES.each do |relative|
      text = File.read(File.expand_path("../#{relative}", __dir__))
      strings = relative.end_with?('.rb') || relative == 'bin/install' ? literals(text) : messages(text)
      offenders = strings.map { |string| string.gsub('@{upstream}', '') }.grep(RETIRED)
      assert_empty offenders, "#{relative} prints a retired word; say the registered branch instead"
    end
  end

  def test_files_owned_by_another_account_need_a_person
    source = Class.new(Shaka::Install::DirectSource) { def trusted_owner?(_entry) = false }
    root = File.join(@directory, 'source')
    error = assert_raises(ArgumentError) do
      source.new(root, ['shaka'], Shaka::Install::Tree.new(['shaka'], source_root: root)).send(:verify_modes)
    end
    assert_includes error.message, 'Installation skills belong to another account'
    assert_includes error.message, "#{File.join(root, 'skills')}, "
    assert_match(/and \d+ more\. Next: a person must decide whether to trust these files; .*, run ls -ln /,
                 error.message)
  end

  private

  def literals(text) = Ripper.lex(text).filter_map { |(_, type, token)| token if type == :on_tstring_content }

  def messages(text) = text.lines.grep_v(/\A\s*#/)
end
