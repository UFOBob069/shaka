# frozen_string_literal: true

require 'rbconfig'
require_relative 'refusal'
require_relative '../ruby_requirement'

module Shaka
  module Install
    # Records the Ruby that ran the installer, which the helper launcher starts with.
    module RubyRecord
      RUBY_RECORD = 'shaka-ruby'

      private

      def record_ruby
        path = File.join(@checkout.root, '.git', RUBY_RECORD)
        temporary = "#{path}.#{Process.pid}"
        File.write(temporary, "#{File.realpath(RbConfig.ruby)}\n", mode: 'wx', perm: 0o600)
        File.rename(temporary, path)
      ensure
        File.unlink(temporary) if temporary && File.exist?(temporary)
      end

      def recorded_ruby?
        record = File.join(@checkout.root, '.git', RUBY_RECORD)
        File.file?(record) && File.executable?(File.read(record).strip)
      end

      def verify_ruby(targets)
        record = File.join(@checkout.root, '.git', RUBY_RECORD)
        ruby = File.read(record).strip
        return if File.executable?(ruby)

        links = targets.map { |target| "#{target.fetch('names').join(', ')} in #{target.fetch('directory')}" }
        raise ArgumentError, Refusal.message(
          "Shaka's installation Ruby is unavailable", "#{ruby}, recorded in #{record}",
          Refusal.command(File.join(@checkout.root, 'bin/install')),
          note: "Run the installer with Ruby #{RubyRequirement::MINIMUM} or newer; " \
                "it keeps the registered skills (#{links.join('; ')})"
        )
      end
    end
  end
end
