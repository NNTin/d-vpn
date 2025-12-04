import logging
import threading
import time
from typing import Dict, List

from flask import Flask, Response, jsonify

from config import Config
from headscale_client import HeadscaleClient
from state_manager import StateManager
from wireguard_manager import WireGuardManager

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(name)s: %(message)s")

app = Flask(__name__)

config = Config()
headscale_client = HeadscaleClient(config.HEADSCALE_URL, config.HEADSCALE_API_KEY)
state_manager = StateManager(config.STATE_FILE_PATH)
wireguard_manager = WireGuardManager(
    config.WIREGUARD_CONFIG_PATH,
    config.WIREGUARD_CONTAINER_NAME,
    config.WIREGUARD_INTERFACE,
    config.WIREGUARD_SUBNET,
    config.WIREGUARD_SERVER_IP,
    config.WIREGUARD_PEER_START_IP,
)

logger = logging.getLogger("sync-service")


def _node_identifier(node: Dict) -> str:
    """Prefer explicit id, fall back to name."""
    return str(node.get("id") or node.get("node_id") or node.get("name"))


def sync_loop() -> None:
    while True:
        try:
            nodes = headscale_client.list_nodes()
            state = state_manager.load_state()
            processed = state.get("processed_nodes", {})

            for node in nodes:
                node_id = _node_identifier(node)
                if not node_id:
                    logger.warning("Skipping node with no identifier: %s", node)
                    continue

                if node_id in processed:
                    continue

                logger.info("Processing new node %s", node_id)
                keys = wireguard_manager.generate_peer_keys(node_id)
                peer_ip = wireguard_manager.allocate_peer_ip(state)
                wireguard_manager.add_peer_to_config(node_id, keys["public_key"], peer_ip)
                wireguard_manager.reload_wireguard()
                state_manager.mark_node_processed(node_id, peer_ip)

                # Keep in-memory view updated to avoid double-processing within same poll.
                processed[node_id] = peer_ip
                state["processed_nodes"] = processed
                state["last_ip"] = peer_ip

                logger.info("Provisioned peer for node %s at %s", node_id, peer_ip)

        except Exception as exc:  # pylint: disable=broad-except
            logger.error("Sync loop error: %s", exc, exc_info=True)

        time.sleep(config.POLL_INTERVAL)


@app.route("/health", methods=["GET"])
def health() -> Response:
    return jsonify({"status": "healthy"})


@app.route("/peer/<node_id>/config", methods=["GET"])
def peer_config(node_id: str) -> Response:
    if not state_manager.is_node_processed(node_id):
        return jsonify({"error": "node not found"}), 404

    peer_ip = state_manager.get_peer_ip(node_id)
    if not peer_ip:
        return jsonify({"error": "peer ip not found"}), 404

    try:
        config_text = wireguard_manager.get_peer_config(node_id, peer_ip)
    except Exception as exc:  # pylint: disable=broad-except
        logger.error("Failed to render config for %s: %s", node_id, exc, exc_info=True)
        return jsonify({"error": "failed to render config"}), 500

    return Response(config_text, mimetype="text/plain")


@app.route("/peers", methods=["GET"])
def peers() -> Response:
    state = state_manager.load_state()
    peers_list: List[Dict[str, str]] = [
        {"node_id": nid, "peer_ip": ip} for nid, ip in state.get("processed_nodes", {}).items()
    ]
    return jsonify(peers_list)


def start_background_sync() -> None:
    thread = threading.Thread(target=sync_loop, daemon=True, name="sync-loop")
    thread.start()


if __name__ == "__main__":
    start_background_sync()
    app.run(host="0.0.0.0", port=config.API_PORT)
