"""Spike-only Docker upload adapter; no capability is added to the agent container."""
from pathlib import Path, PurePosixPath

from harbor.environments.docker.docker import DockerEnvironment


class CapabilityUploadDocker(DockerEnvironment):
    async def upload_file(self, source_path, target_path):
        target = str(target_path)
        if target not in {
            "/tmp/codex-secrets/auth.json",
            "/tmp/codex-home/config.toml",
        }:
            return await super().upload_file(source_path, target_path)

        # Feed bytes on stdin rather than putting a credential in argv or logs.
        # The image's USER remains agent; an explicit task user is unnecessary.
        await self._run_docker_compose_command(
            [
                "exec", "-T", "-u", "agent", "main", "sh", "-c",
                'umask 077; mkdir -p "$1" && cat > "$2" && chmod 600 "$2"',
                "spike-upload", str(PurePosixPath(target).parent), target,
            ],
            check=True,
            stdin_data=Path(source_path).read_bytes(),
        )
