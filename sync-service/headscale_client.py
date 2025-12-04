import logging
from typing import Any, Dict, List, Optional

import requests


class HeadscaleClient:
    """Thin wrapper around the Headscale REST API."""

    def __init__(self, base_url: str, api_key: str) -> None:
        self.base_url = base_url.rstrip("/")
        self.session = requests.Session()
        self.session.headers.update({"Authorization": f"Bearer {api_key}"})
        self.logger = logging.getLogger(__name__)

    def _request(self, method: str, path: str, **kwargs: Any) -> Any:
        url = f"{self.base_url}{path}"
        self.logger.debug("Headscale request: %s %s", method, url)
        resp = self.session.request(method, url, timeout=10, **kwargs)

        if not resp.ok:
            self.logger.error("Headscale API error %s %s: %s", method, url, resp.text)
            resp.raise_for_status()

        try:
            return resp.json()
        except ValueError as exc:
            self.logger.error("Failed to parse JSON from Headscale response: %s", exc)
            raise

    def list_nodes(self) -> List[Dict[str, Any]]:
        """Return a list of nodes from Headscale."""
        data = self._request("GET", "/api/v1/node")
        # Some Headscale versions wrap results in {"nodes": [...]}
        if isinstance(data, dict) and "nodes" in data:
            return data.get("nodes", [])
        if isinstance(data, list):
            return data
        self.logger.warning("Unexpected response shape from list_nodes: %s", data)
        return []

    def get_node(self, node_id: str) -> Optional[Dict[str, Any]]:
        """Return a single node by ID."""
        try:
            return self._request("GET", f"/api/v1/node/{node_id}")
        except requests.HTTPError as exc:
            if exc.response is not None and exc.response.status_code == 404:
                self.logger.info("Node %s not found in Headscale.", node_id)
                return None
            raise
