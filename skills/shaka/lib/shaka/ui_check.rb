# frozen_string_literal: true

require 'json'
require 'optparse'
require_relative 'error'
require_relative 'github'
require_relative 'ui_check/publisher'

module Shaka
  # Publishes a UI check comment and folds this account's earlier UI checks beneath it.
  module UiCheck
    USAGE = 'Usage: shaka ui-check OWNER/REPO NUMBER --head SHA --content-file PATH'

    module_function

    def run(arguments, github: nil, publisher: Publisher)
      options = parse(arguments)
      return 0 unless options

      github ||= GitHub.new(*arguments)
      result = publisher.new(github).call(head: options.fetch(:head), content: content(options.fetch(:content)))
      puts JSON.pretty_generate(result)
      result['unavailable'].empty? ? 0 : 1
    rescue Error, OptionParser::ParseError => e
      warn "shaka: #{e.message}"
      1
    end

    def parse(arguments)
      options = {}
      parser = option_parser(options)
      parser.parse!(arguments)
      return nil.tap { puts parser } if options[:help]
      raise OptionParser::InvalidArgument, parser.to_s unless arguments.length == 2 && options.key?(:content)
      raise OptionParser::MissingArgument, '--head' unless options[:head]

      options
    end

    def option_parser(options)
      OptionParser.new do |flags|
        flags.banner = USAGE
        flags.on('-h', '--help') { options[:help] = true }
        flags.on('--head SHA', /\A\h{40}\z/, 'PR head the captures show') { |sha| options[:head] = sha }
        flags.on('--content-file PATH', 'JSON: identity, body, captures, retire') { |path| options[:content] = path }
      end
    end

    def content(path)
      parsed = JSON.parse(File.read(path, encoding: 'UTF-8'))
      raise Error, 'UI check content must be a JSON object.' unless parsed.is_a?(Hash)

      parsed
    rescue JSON::ParserError, SystemCallError => e
      raise Error, "UI check content is unreadable: #{e.message}"
    end
  end
end
