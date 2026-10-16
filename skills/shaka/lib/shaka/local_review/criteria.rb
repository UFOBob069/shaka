# frozen_string_literal: true

module Shaka
  # Loads only review criteria present at the separately verified trusted commit.
  module LocalReviewCriteria
    LINK_MODE = '120000'
    FILE_MODES = %w[100644 100755].freeze
    MAX_LINKS = 40

    # Resolves a path one component at a time within one tree, expanding each link before any
    # later `..`, as the filesystem does. Returns the regular file path, or nil when a link is
    # empty or absolute, the path leaves the repository or dangles, links cycle, or it ends at a
    # non-file entry.
    def self.resolve(entries, path, &read_link)
      TreeWalk.new(entries, read_link).run(path)
    end

    # One component-by-component path walk over a trusted tree's entries.
    class TreeWalk
      def initialize(entries, read_link)
        @entries = entries
        @read_link = read_link
        @resolved = []
        @links = 0
      end

      def run(path)
        @pending = path.split('/')
        until @pending.empty?
          part = @pending.shift
          next if ['', '.'].include?(part)
          return nil unless part == '..' ? parent : enter(part)
        end
        file = @resolved.join('/')
        file if FILE_MODES.include?(@entries.dig(file, 0))
      end

      private

      def parent
        @resolved.pop
      end

      # A non-link component must be a directory in the tree, or the final regular file.
      def enter(part)
        path = [*@resolved, part].join('/')
        mode, object = @entries[path]
        return follow(object) if mode == LINK_MODE
        return false unless mode ? @pending.empty? : directory?(path)

        @resolved.push(part)
      end

      def follow(object)
        target = @read_link.call(object)
        return false if (@links += 1) > MAX_LINKS || target.empty? || target.start_with?('/')

        # A limit of -1 keeps a trailing slash as an empty component, so `file/` stays invalid.
        @pending.unshift(*target.split('/', -1))
      end

      def directory?(path)
        @directories ||= @entries.keys.each_with_object(Set.new) do |key, directories|
          parts = key.split('/')
          (1...parts.length).each { |count| directories << parts.first(count).join('/') }
        end
        @directories.include?(path)
      end
    end

    private

    def trusted_criteria(marker)
      ref = @options[:criteria_ref]
      return '' unless ref

      entries = trusted_tree(ref)
      sources = applicable_criteria(entries)
      @criteria_supplied = sources.any? { |_path, source| source }
      sources.map { |path, source| criteria_block(ref, marker, path, source && entries.fetch(source).last) }.join
    end

    def criteria_block(ref, marker, origin, object)
      label = "TRUSTED CRITERIA #{marker}"
      return "--- #{label} NOT SUPPLIED: #{ref}:#{origin} does not resolve to a file in the repository ---\n\n" unless
        object

      text = capture(git_executable, '-C', root, 'cat-file', 'blob', object)
      "--- BEGIN #{label} FROM #{ref}:#{origin} ---\n#{text}\n--- END #{label} ---\n\n"
    end

    # Pairs each applicable AGENTS.md with the regular file it resolves to at the trusted commit, or nil.
    def applicable_criteria(entries)
      paths = capture(git_executable, '-C', root, 'diff', '--no-renames', '--name-only', '-z',
                      "#{@options[:base]}...#{head}", '--').split("\0")
      entries.keys.select { |file| applicable_agents_file?(file, paths) }
             .sort_by { |file| [file.count('/'), file] }
             .map { |file| resolved_criteria(entries, file) }
    end

    def trusted_tree(ref)
      capture(git_executable, '-C', root, 'ls-tree', '-r', '-z', ref, '--').split("\0").to_h do |line|
        metadata, path = line.split("\t", 2)
        mode, _type, object = metadata.split(' ', 3)
        [path, [mode, object]]
      end
    end

    def resolved_criteria(entries, file)
      source = LocalReviewCriteria.resolve(entries, file) do |object|
        capture(git_executable, '-C', root, 'cat-file', 'blob', object)
      end
      [source.nil? || source == file ? file : "#{file} -> #{source}", source]
    end

    def applicable_agents_file?(file, changed_paths)
      return true if file == 'AGENTS.md'
      return false unless file.end_with?('/AGENTS.md')

      directory = File.dirname(file)
      changed_paths.any? { |path| path.start_with?("#{directory}/") }
    end
  end
end
