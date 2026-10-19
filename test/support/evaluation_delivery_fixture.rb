# frozen_string_literal: true

module EvaluationDeliveryFixture
  HEAD = 'a' * 40
  NODE = 'PRR_synthetic'

  def setup
    @directory = Dir.mktmpdir('delivery-readback')
    @response = File.join(@directory, 'response.json')
    @gh = File.join(@directory, 'gh')
    source = File.read(File.expand_path('../fixtures/evaluation_delivery/gh.txt', __dir__))
    File.write(@gh, "#!#{RbConfig.ruby}\n#{source}")
    File.chmod(0o755, @gh)
    write_review
  end

  def teardown = FileUtils.remove_entry(@directory)

  def review
    { 'id' => NODE, 'fullDatabaseId' => '5566107686', 'state' => 'COMMENTED', 'body' => 'fixture review',
      'createdAt' => '2026-10-18T00:00:00Z', 'updatedAt' => '2026-10-18T00:00:01Z',
      'submittedAt' => '2026-10-18T00:00:01Z',
      'commit' => { 'oid' => HEAD }, 'author' => { 'login' => 'fixture-agent' },
      'pullRequest' => { 'number' => 1, 'state' => 'OPEN', 'headRefOid' => HEAD,
                         'repository' => { 'nameWithOwner' => 'fixture-org/cell' } } }
  end

  def write_review(row = review) = File.write(@response, JSON.generate({ 'data' => { 'node' => row } }))

  def reader(**)
    Shaka::Evaluation::DeliveryReadback.new(repository: 'fixture-org/cell', number: 1, head: HEAD, github: @gh,
                                            **)
  end

  def capture = reader.read(node_id: NODE, review_id: 5_566_107_686, actor: 'fixture-agent')
end
