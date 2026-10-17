# frozen_string_literal: true

require 'yaml'
require_relative 'error'
require_relative 'repository_config/duplicate_keys'

module Shaka
  # Reads the packaged built-in defaults that apply when a repository omits a setting.
  module Defaults
    PATH = File.expand_path('../../config/defaults.yml', __dir__)
    SECTIONS = %w[review merge branches wip pr_description prose_limits project_guidance runtime].freeze

    def self.fetch(*keys)
      keys.reduce(data) do |node, key|
        next node.fetch(key) if node.is_a?(Hash) && node.key?(key)

        raise Error, "#{PATH} has no #{keys.join('.')}"
      end
    end

    def self.data
      @data ||= load(File.read(PATH, encoding: 'UTF-8'))
    rescue Errno::ENOENT, Errno::EACCES => e
      raise Error, "Shaka's built-in defaults are unreadable: #{e.message}"
    end

    def self.load(source)
      RepositoryConfig::DuplicateKeys.check(source, filename: 'defaults.yml')
      data = YAML.safe_load(source, permitted_classes: [], permitted_symbols: [], aliases: false)
      raise Error, "Invalid #{PATH}: expected a mapping" unless data.is_a?(Hash)
      raise Error, "Invalid #{PATH}: sections must be #{SECTIONS.join(', ')}" unless data.keys.sort == SECTIONS.sort

      deep_freeze(data)
    rescue Psych::Exception => e
      raise Error, "Invalid #{PATH}: #{e.message}"
    end

    def self.deep_freeze(value)
      case value
      when Hash then value.each_value { |item| deep_freeze(item) }
      when Array then value.each { |item| deep_freeze(item) }
      end
      value.freeze
    end
    private_class_method :deep_freeze
  end
end
