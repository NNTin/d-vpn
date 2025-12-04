import os

from dotenv import load_dotenv

load_dotenv()


class Config:
    """Simple config loader for environment-backed settings."""

    HEADSCALE_URL = os.getenv("HEADSCALE_URL", "http://headscale:8080")
    HEADSCALE_API_KEY = os.getenv("HEADSCALE_API_KEY")

    WIREGUARD_CONTAINER_NAME = os.getenv("WIREGUARD_CONTAINER_NAME", "wireguard-server")
    WIREGUARD_CONFIG_PATH = os.getenv("WIREGUARD_CONFIG_PATH", "/config")
    WIREGUARD_INTERFACE = os.getenv("WIREGUARD_INTERFACE", "wg0")
    WIREGUARD_SUBNET = os.getenv("WIREGUARD_SUBNET", "10.13.13.0/24")
    WIREGUARD_SERVER_IP = os.getenv("WIREGUARD_SERVER_IP", "10.13.13.1")
    WIREGUARD_PEER_START_IP = os.getenv("WIREGUARD_PEER_START_IP", "10.13.13.2")

    POLL_INTERVAL = int(os.getenv("POLL_INTERVAL", "30"))
    STATE_FILE_PATH = os.getenv("STATE_FILE_PATH", f"{WIREGUARD_CONFIG_PATH}/sync-service-state.json")
    API_PORT = int(os.getenv("API_PORT", "5000"))


if not Config.HEADSCALE_API_KEY:
    raise RuntimeError("HEADSCALE_API_KEY is required for sync service operation.")
