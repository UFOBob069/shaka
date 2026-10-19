# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/executable_file'

class ExecutableFileTest < Minitest::Test
  def test_a_shebang_script_is_executable_when_the_platform_stores_no_bit
    skip 'the executable bit is stored' unless Shaka::ExecutableFile.windows?

    Dir.mktmpdir do |dir|
      path = File.join(dir, 'setup')
      File.write(path, "#!/bin/sh\nexit 0\n")
      File.chmod(0o755, path)

      refute File.executable?(path)
      assert Shaka::ExecutableFile.executable?(path)
    end
  end

  def test_a_shebang_without_the_executable_bit_stays_non_executable
    skip 'this platform does not store an executable bit' if Shaka::ExecutableFile.windows?

    Dir.mktmpdir do |dir|
      path = File.join(dir, 'setup')
      File.write(path, "#!/bin/sh\nexit 0\n")
      File.chmod(0o644, path)

      refute Shaka::ExecutableFile.executable?(path)
    end
  end

  def test_a_file_without_a_shebang_is_not_executable_on_windows
    skip 'the executable bit is stored' unless Shaka::ExecutableFile.windows?

    Dir.mktmpdir do |dir|
      path = File.join(dir, 'setup')
      File.write(path, "exit 0\n")

      refute Shaka::ExecutableFile.executable?(path)
    end
  end
end
