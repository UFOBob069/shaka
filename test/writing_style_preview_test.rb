# frozen_string_literal: true

require_relative 'settings_preview_fixture'
require 'shaka/seam'

class WritingStylePreviewTest < Minitest::Test
  include SettingsPreviewFixture

  def test_settings_preview_keeps_the_callers_trusted_writing_guide
    with_guide_preview do |root, trusted, preview|
      payload = Shaka::Seam::CheckReport.from_ref(root:, ref: trusted).to_h

      assert_equal 'preview/local', payload.dig('validation', 'mode')
      assert_equal preview, payload.dig('validation', 'sha')
      assert_false payload.dig('validation', 'grants_merge_authority')
      assert_equal 'preview-model', payload.dig('review', 'local_review_agents', 0, 'model')
      assert_equal 'Trusted style.', payload.dig('writing_style', 'guide')
    end
  end

  private

  def with_guide_preview
    with_preview_repository do |root, _trusted, _preview|
      trusted = commit_style(root, 'Trusted style.')
      git(root, 'checkout', 'settings')
      preview = commit_style(root, 'Preview style.')
      git(root, 'checkout', 'feature')
      File.write(File.join(root, '.agents/writing-style.md'), "Candidate style.\n")
      select_preview(root, preview)
      yield root, trusted, preview
    end
  end

  def commit_style(root, text)
    File.write(File.join(root, '.agents/writing-style.md'), "#{text}\n")
    commit(root)
  end
end
