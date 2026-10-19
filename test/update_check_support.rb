# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/update_check'

# Runs update-check against canned git and GitHub answers and records each command.
module UpdateCheckSupport
  SHA = 'a' * 40
  PULLED = 'b' * 40
  CHECKOUT = '/installed path'
  SOURCE = { 'kind' => 'revision', 'revision' => SHA,
             'repository' => 'https://github.com/shakacode/shaka.git' }.freeze
  DEFAULTS = { source: SOURCE, branch: 'main', checkout: CHECKOUT, ahead_by: 3, head: SHA, github: nil,
               published: ['', '', true], pulled: ['', '', true] }.freeze

  def check(status, **options)
    @options = DEFAULTS.merge(options)
    @calls = []
    @github = @options[:github] || [JSON.generate({ 'status' => status, 'ahead_by' => @options[:ahead_by],
                                                    'oldest' => '2020-01-01T00:00:00Z' }), '', true]
    Shaka::UpdateCheck.new(source: @options[:source], branch: @options[:branch], checkout: @options[:checkout],
                           helper: '/installed path/scripts/shaka', runner: method(:answer)).result
  end

  def answer(argv, directory)
    @calls << [argv, directory]
    return @github unless argv.first == 'git'
    return ["#{@options[:head]}\n", '', true] unless argv.include?('merge-base')

    argv.last.start_with?('refs/') ? @options[:published] : @options[:pulled]
  end
end
