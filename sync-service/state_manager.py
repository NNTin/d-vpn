import json
import logging
import os
import tempfile
import threading
from typing import Dict, Optional


class StateManager:
    """Persist processed nodes and IP allocations."""

    def __init__(self, state_file_path: str) -> None:
        self.state_file_path = state_file_path
        self.lock = threading.Lock()
        self.logger = logging.getLogger(__name__)

    def _default_state(self) -> Dict[str, Dict[str, str]]:
        return {"processed_nodes": {}, "last_ip": None}

    def load_state(self) -> Dict[str, Dict[str, str]]:
        with self.lock:
            if not os.path.exists(self.state_file_path):
                self.logger.info("State file not found, initializing new state at %s", self.state_file_path)
                return self._default_state()

            try:
                with open(self.state_file_path, "r", encoding="utf-8") as fh:
                    return json.load(fh)
            except (json.JSONDecodeError, OSError) as exc:
                self.logger.error("Failed to load state file %s: %s", self.state_file_path, exc)
                return self._default_state()

    def save_state(self, state: Dict[str, Dict[str, str]]) -> None:
        with self.lock:
            os.makedirs(os.path.dirname(self.state_file_path), exist_ok=True)
            fd, temp_path = tempfile.mkstemp(prefix="sync-state-", dir=os.path.dirname(self.state_file_path))
            try:
                with os.fdopen(fd, "w", encoding="utf-8") as tmp:
                    json.dump(state, tmp, indent=2)
                os.replace(temp_path, self.state_file_path)
            except OSError as exc:
                self.logger.error("Failed to persist state to %s: %s", self.state_file_path, exc)
                raise
            finally:
                if os.path.exists(temp_path):
                    try:
                        os.remove(temp_path)
                    except OSError:
                        pass

    def mark_node_processed(self, node_id: str, peer_ip: str) -> None:
        state = self.load_state()
        state["processed_nodes"][str(node_id)] = peer_ip
        state["last_ip"] = peer_ip
        self.save_state(state)

    def is_node_processed(self, node_id: str) -> bool:
        state = self.load_state()
        return str(node_id) in state.get("processed_nodes", {})

    def get_peer_ip(self, node_id: str) -> Optional[str]:
        state = self.load_state()
        return state.get("processed_nodes", {}).get(str(node_id))
