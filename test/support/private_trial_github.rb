# frozen_string_literal: true

module PrivateTrialGitHub
  SCRIPT = <<~'RUBY'
    require 'json'
    directory = File.dirname(__FILE__)
    fixture = JSON.parse(File.read(File.join(directory, 'fixture.json')))
    head = fixture.fetch('head')
    review_file = File.join(directory, 'review.json')
    reviews = File.exist?(review_file) ? [JSON.parse(File.read(review_file))] : []
    raw = STDIN.read
    request = raw.strip.empty? ? {} : JSON.parse(raw)
    path = ARGV[1]
    result = case path
             when 'checks'
               [{ 'name' => 'validate', 'state' => 'SUCCESS', 'bucket' => 'pass' }]
             when 'graphql'
               { 'data' => { 'repository' => { 'pullRequest' =>
                 { 'headRefOid' => head, 'state' => 'OPEN', 'baseRefName' => 'main',
                   'reviewThreads' => { 'nodes' => [], 'pageInfo' => { 'hasNextPage' => false } } } } } }
             when 'repos/owner/repo' then { 'visibility' => 'private' }
             when %r{/rules/branches/} then []
             when 'user' then { 'login' => 'shaka-agent' }
             when 'markdown' then '<p>Feature verified.</p><table></table>'
             when %r{/pulls/1/files} then [{ 'filename' => 'README.md' }]
             when %r{/pulls/1/comments} then []
             when %r{/pulls/1/reviews/7} then reviews.fetch(0)
             when %r{/pulls/1/reviews}
               if ARGV.include?('POST')
                 review = { 'id' => 7, 'state' => 'COMMENTED', 'commit_id' => head,
                            'body' => request.fetch('body'), 'user' => { 'login' => 'shaka-agent' },
                            'submitted_at' => '2026-10-02T00:00:00Z' }
                 File.write(review_file, JSON.generate(review))
                 review
               else
                 reviews
               end
             when %r{/issues/1/labels} then [{ 'name' => 'awaiting-resume' }]
             when %r{/issues/1/comments} then []
             when %r{/pulls/1}
               { 'body' => fixture.fetch('body'), 'head' => { 'sha' => head } }
             else abort "unexpected request: #{ARGV.inspect}"
             end
    puts JSON.generate(result)
  RUBY
end
