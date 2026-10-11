# frozen_string_literal: true

require_relative 'private_delivery_helper'

class PrivateCheckpointTest < Minitest::Test
  include PrivateDeliveryFixture

  def test_private_opt_out_cannot_bypass_final_preparation
    with_trial do
      prepare_private_opt_out
      invoke('squash-message', '--head', @ref, '--content-file', message_file,
             exit_code: 1, error: 'Post-implementation review is missing')
      resumed = invoke('handoff', exit_code: 2)
      assert(resumed['owed'].any? { |item| item.include?('Post-implementation review is missing') })
    end
  end

  def test_private_final_preparation_rejects_stale_review
    with_trial do
      prepare_private_opt_out
      alter_pull { |pull| pull['comments'] = [product_review('d' * 40)] }
      invoke('squash-message', '--head', @ref, '--content-file', message_file,
             exit_code: 1, error: 'Post-implementation review is missing')
      resumed = invoke('handoff', exit_code: 2)
      assert(resumed['owed'].any? { |item| item.include?('Post-implementation review is missing') })
    end
  end

  def test_private_final_preparation_accepts_current_review
    with_trial do
      prepare_private_opt_out
      alter_pull { |pull| pull['comments'] = [product_review(@ref)] }
      assert_equal 10, invoke('squash-message', '--head', @ref, '--content-file', message_file)['id']
      assert_empty invoke('handoff')['owed']
    end
  end

  private

  def prepare_private_opt_out
    update_private { |data| data['review']['post_implementation'] = { 'enabled' => false } }
    publish_delivery
    alter_pull do |pull|
      pull['labels'] = [{ 'name' => 'awaiting-merge-approval' }]
      pull['snapshot']['commits'] = { 'totalCount' => 1 }
    end
  end

  def message_file
    path = File.join(@state, 'message.json')
    File.write(path, JSON.generate('title' => 'Fix', 'body' => 'Private delivery works.'))
    path
  end

  def product_review(head)
    body = "<!-- shaka:reply:post-implementation-#{head[0, 7]}-abc12345 -->\nReport\n\n" \
           "<!-- shaka:post-implementation #{head} ready -->"
    { 'id' => 1, 'user' => { 'login' => 'shaka-agent' }, 'body' => body }
  end
end
