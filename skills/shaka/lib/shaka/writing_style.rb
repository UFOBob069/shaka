# frozen_string_literal: true

require 'open3'
require_relative 'error'
require_relative 'trusted_path_resolver'

module Shaka
  # Reads the optional repository writing guide from one trusted conventional path.
  class WritingStyle
    PATH = '.agents/writing-style.md'
    # Bound memory and prompt use before reading the trusted blob.
    MAX_BYTES = 100 * 1024

    def self.load(root:, sha:)
      entry = TrustedPathResolver.new(root:, sha:).entry(PATH)
      return unless entry

      label = "#{PATH} at #{sha}"
      raise Error, "#{label} must be a regular file, not a symlink" if entry == TrustedPathResolver::SYMLINK
      raise Error, "#{label} must be a regular file" unless entry.last == 'blob'

      validate_size!(Integer(git_output(root, sha, '-s'), 10), label:)
      parse(git_output(root, sha, '-p'), label:)
    end

    def self.validate_candidate(root:)
      path = File.join(root, PATH)
      stat = File.lstat(path)
      validate_candidate_type!(stat)

      validate_size!(stat.size, label: PATH)
      parse(File.binread(path), label: PATH)
      nil
    rescue Errno::ENOENT
      nil
    rescue SystemCallError => e
      raise Error, "Cannot read #{PATH}: #{e.class}"
    end

    def self.validate_candidate_type!(stat)
      raise Error, "#{PATH} must be a regular file, not a symlink" if stat.symlink?
      raise Error, "#{PATH} must be a regular file" unless stat.file?
    end
    private_class_method :validate_candidate_type!

    def self.parse(source, label:)
      guide = source.dup.force_encoding(Encoding::UTF_8)
      raise Error, "#{label} must contain valid UTF-8" unless guide.valid_encoding?

      guide = guide.strip
      raise Error, "#{label} must not be empty" if guide.empty?

      { 'guide' => guide }
    end

    def self.validate_size!(size, label:)
      return if size <= MAX_BYTES

      raise Error, "#{label} must not exceed #{MAX_BYTES} bytes"
    end

    def self.optional
      [yield, nil]
    rescue Error => e
      warning = "ignoring invalid optional writing style: #{e.message}"
      warn "shaka: #{warning}"
      [nil, warning]
    end

    def self.git_output(root, sha, option)
      text, error, status = Open3.capture3('git', '-C', root, 'cat-file', option, "#{sha}:#{PATH}", binmode: true)
      raise Error, "Cannot read #{PATH} at #{sha}: #{error.strip}" unless status.success?

      text
    end
    private_class_method :git_output
  end
end
