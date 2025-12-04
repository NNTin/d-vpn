import ipaddress
import logging
import os
import subprocess
import threading
from typing import Dict, Optional

import docker


class WireGuardManager:
    """Manage WireGuard peer provisioning and config updates."""

    def __init__(
        self,
        config_path: str,
        container_name: str,
        interface_name: str,
        subnet: str,
        server_ip: str,
        peer_start_ip: str,
    ) -> None:
        self.config_path = config_path
        self.container_name = container_name
        self.interface_name = interface_name
        self.subnet = ipaddress.ip_network(subnet, strict=False)
        self.server_ip = ipaddress.ip_address(server_ip)
        self.peer_start_ip = ipaddress.ip_address(peer_start_ip)

        self.config_file = os.path.join(self.config_path, "wg_confs", f"{self.interface_name}.conf")
        self.template_path = os.path.join(self.config_path, "templates", "peer.conf")
        self.peers_dir = os.path.join(self.config_path, "peers")
        self.lock = threading.Lock()
        self.logger = logging.getLogger(__name__)
        self.docker_client = docker.from_env()

    def generate_peer_keys(self, peer_id: str) -> Dict[str, str]:
        """Generate and store private/public/preshared keys for a peer."""
        peer_dir = os.path.join(self.peers_dir, str(peer_id))
        os.makedirs(peer_dir, exist_ok=True)

        private_key = subprocess.run(["wg", "genkey"], capture_output=True, text=True, check=True).stdout.strip()
        public_key = subprocess.run(
            ["wg", "pubkey"], input=private_key, capture_output=True, text=True, check=True
        ).stdout.strip()
        preshared_key = subprocess.run(["wg", "genpsk"], capture_output=True, text=True, check=True).stdout.strip()

        with open(os.path.join(peer_dir, "privatekey"), "w", encoding="utf-8") as fh:
            fh.write(private_key)
        with open(os.path.join(peer_dir, "publickey"), "w", encoding="utf-8") as fh:
            fh.write(public_key)
        with open(os.path.join(peer_dir, "presharedkey"), "w", encoding="utf-8") as fh:
            fh.write(preshared_key)

        os.chmod(os.path.join(peer_dir, "privatekey"), 0o600)

        self.logger.info("Generated keys for peer %s", peer_id)
        return {"private_key": private_key, "public_key": public_key, "preshared_key": preshared_key}

    def allocate_peer_ip(self, state: Dict[str, Dict[str, str]]) -> str:
        """Allocate the next available IP address for a peer."""
        used_ips = set(state.get("processed_nodes", {}).values())
        last_ip = state.get("last_ip")

        candidate = ipaddress.ip_address(last_ip) + 1 if last_ip else self.peer_start_ip
        if candidate < self.peer_start_ip:
            candidate = self.peer_start_ip

        while True:
            if candidate == self.server_ip or str(candidate) in used_ips:
                candidate += 1
                continue
            if candidate not in self.subnet:
                raise RuntimeError("WireGuard subnet exhausted; no IPs available for new peers.")
            break

        state["last_ip"] = str(candidate)
        self.logger.info("Allocated IP %s", candidate)
        return str(candidate)

    def add_peer_to_config(self, peer_id: str, public_key: str, peer_ip: str) -> None:
        """Append a peer entry to wg0.conf."""
        os.makedirs(os.path.dirname(self.config_file), exist_ok=True)
        peer_block = (
            "\n[Peer]\n"
            f"PublicKey = {public_key}\n"
            f"AllowedIPs = {peer_ip}/32\n"
            "\n"
        )

        with self.lock:
            with open(self.config_file, "a", encoding="utf-8") as fh:
                fh.write(peer_block)
        self.logger.info("Added peer %s with IP %s to config %s", peer_id, peer_ip, self.config_file)

    def reload_wireguard(self) -> None:
        """Trigger WireGuard to reload configuration."""
        container = self.docker_client.containers.get(self.container_name)
        cmd = [
            "bash",
            "-c",
            f"wg syncconf {self.interface_name} <(wg-quick strip /config/wg_confs/{self.interface_name}.conf)",
        ]
        result = container.exec_run(cmd, stdout=True, stderr=True)
        if result.exit_code != 0:
            self.logger.error("WireGuard reload failed: %s", result.output.decode("utf-8", errors="ignore"))
            raise RuntimeError(f"WireGuard reload failed with exit code {result.exit_code}")
        self.logger.info("WireGuard configuration reloaded.")

    def _read_file(self, path: str) -> Optional[str]:
        try:
            with open(path, "r", encoding="utf-8") as fh:
                return fh.read().strip()
        except OSError as exc:
            self.logger.error("Failed to read %s: %s", path, exc)
            return None

    def get_peer_config(self, peer_id: str, peer_ip: str) -> str:
        """Render and return the peer WireGuard configuration."""
        template = self._read_file(self.template_path)
        if template is None:
            raise FileNotFoundError(f"Peer template not found at {self.template_path}")

        peer_dir = os.path.join(self.peers_dir, str(peer_id))
        private_key = self._read_file(os.path.join(peer_dir, "privatekey"))
        public_key = self._read_file(os.path.join(peer_dir, "publickey"))
        preshared_key = self._read_file(os.path.join(peer_dir, "presharedkey"))
        server_public_key = self._read_file(os.path.join(self.config_path, "server", "publickey-server"))

        if None in (private_key, public_key, server_public_key, preshared_key):
            raise FileNotFoundError(f"Missing key material for peer {peer_id}")

        rendered = template
        replacements = {
            "${CLIENT_IP}": f"{peer_ip}/32",
            "${PEER_ID}": str(peer_id),
            "${PEERDNS}": str(self.server_ip),
            "${SERVERURL}": str(self.server_ip),
            "${SERVERPORT}": "51820",
            "${ALLOWEDIPS}": str(self.subnet),
            f"$(cat /config/{peer_id}/privatekey-{peer_id})": private_key,
            f"$(cat /config/{peer_id}/presharedkey-{peer_id})": preshared_key,
            "$(cat /config/server/publickey-server)": server_public_key,
        }

        for placeholder, value in replacements.items():
            rendered = rendered.replace(placeholder, value)

        return rendered
