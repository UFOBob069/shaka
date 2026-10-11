# frozen_string_literal: true

require 'json'

# Persistent API state lets separate CLI processes publish, then resume the same fixture PR.
path = File.join(Dir.home, 'pull.json')
pull = JSON.parse(File.read(path))
raw = $stdin.read
request = raw.empty? ? {} : JSON.parse(raw)
endpoint = ARGV[1].to_s
result = case ARGV.first
         when 'pr'
           if ARGV.include?('--required')
             pull.fetch('native_checks', [])
           else
             pull.fetch('checks', [])
           end
         when 'api'
           case endpoint
           when 'graphql' then { 'data' => { 'repository' => { 'pullRequest' => pull['snapshot'] } } }
           when 'markdown'
             text = request.fetch('text').gsub(%r{<details>.*?</details>}m, '')
             paragraphs = text.split(/\n\s*\n/).reject { |block| block.start_with?('|') }
             puts ('<table></table>' * 10) + paragraphs.map { |block| "<p>#{block}</p>" }.join
             exit
           when 'user' then { 'login' => 'shaka-agent' }
           when %r{/rules/branches/} then []
           when %r{/comments}
             if ARGV.include?('POST')
               posted = request.merge('id' => 10, 'user' => { 'login' => 'shaka-agent' },
                                      'html_url' => 'https://github.com/owner/repo/pull/1#issuecomment-10')
               (pull['comments'] ||= []) << posted
               posted
             else
               pull.fetch('comments', [])
             end
           when %r{/labels} then pull.fetch('labels', [{ 'name' => 'awaiting-resume' }])
           when %r{/commits} then [{ 'commit' => { 'message' => 'Feature' } }]
           when %r{/files} then [{ 'filename' => 'feature' }]
           when %r{/reviews/7} then pull.fetch('review')
           when %r{/reviews}
             if ARGV.include?('POST')
               pull['review'] = request.merge('id' => 7, 'state' => 'COMMENTED',
                                              'submitted_at' => '2026-10-01T00:00:00Z',
                                              'user' => { 'login' => 'shaka-agent' })
             else
               [pull['review']].compact
             end
           when %r{/pulls/1\z}
             if ARGV.include?('PATCH')
               pull['body'] = request.fetch('body')
               File.write(File.join(Dir.home, 'published.md'), pull['body'])
             end
             { 'head' => { 'sha' => pull['snapshot']['headRefOid'] }, 'body' => pull.fetch('body', ''),
               'changed_files' => 1, 'additions' => 1, 'deletions' => 0 }
           else abort "Unexpected endpoint #{endpoint}"
           end
         else abort "Unexpected command #{ARGV.inspect}"
         end
File.write(path, JSON.generate(pull))
puts JSON.generate(result)
