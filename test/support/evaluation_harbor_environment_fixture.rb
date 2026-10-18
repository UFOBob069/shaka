# frozen_string_literal: true

module EvaluationHarborEnvironmentFixture
  def container_readbacks(name = 'shaka-synthetic')
    %w[env verifier__trial].product(%w[main harbor-docker-egress-control-sidecar]).map do |role, service|
      container_readback(name, role, service)
    end
  end

  def container_readback(name, role, service)
    { 'Id' => "private-id-#{role}-#{service}", 'Image' => "sha256:#{'a' * 64}",
      'Config' => { 'User' => 'agent', 'Env' => ['PRIVATE=synthetic-secret'], 'Labels' => {
        'com.docker.compose.project' => "#{name}__#{role}", 'com.docker.compose.service' => service
      } },
      'HostConfig' => container_controls,
      'Mounts' => [{ 'Source' => '/private/controller/skill', 'Destination' => '/opt/shaka',
                     'RW' => false, 'Type' => 'bind' }] }
  end

  def container_controls
    { 'NanoCpus' => 2_000_000_000, 'Memory' => 2_147_483_648,
      'ReadonlyRootfs' => true, 'Init' => true, 'PidsLimit' => 256,
      'CapDrop' => ['ALL'], 'CapAdd' => nil, 'SecurityOpt' => ['no-new-privileges:true'],
      'Sysctls' => { 'net.ipv4.ping_group_range' => '0 0' } }
  end
end
