# frozen_string_literal: true

require 'json'
require 'optparse'
require_relative 'bundle'

module Shaka
  # One JSON document per ledger for later evaluation: the ledger as recorded, with each round's
  # kept report text or the reason it is unavailable. It derives no labels and generates no
  # timestamps or identifiers, so one ledger always exports the same bytes. Report text is
  # unpublished review content, so the export is as private as the ledger.
  module LocalReviewExport
    VERSION = 1

    module_function

    def run(arguments, **)
      ledger = nil
      parser = OptionParser.new('Usage: shaka review export --ledger PATH')
      parser.on('--ledger PATH') { |value| ledger = value }
      rest = parser.parse(arguments)
      raise OptionParser::InvalidArgument, parser.to_s unless rest.empty? && ledger

      puts JSON.pretty_generate(document(ledger))
      0
    end

    def document(path)
      ledger = LocalReviewBundle.ledger!(JSON.parse(File.read(path, encoding: 'UTF-8')), path)
      directory = File.dirname(File.expand_path(path))
      rounds = ledger['rounds'].map { |round| with_report(round, directory) }
      { 'export_version' => VERSION, 'ledger_version' => ledger['version'] }
        .merge(ledger.except('version'), 'rounds' => rounds)
    end

    def with_report(round, directory)
      return round unless round.is_a?(Hash) && round['report'].is_a?(String)

      file, reason = LocalReviewBundle.kept(round, directory)
      return round.merge('report_unavailable' => reason) if reason

      text = File.read(file, encoding: 'UTF-8')
      return round.merge('report_unavailable' => "#{file} is not valid UTF-8") unless text.valid_encoding?

      round.merge('report_text' => text)
    end

    private_class_method :with_report
  end
end
