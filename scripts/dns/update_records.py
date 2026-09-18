"""DNS record update utility for ServerFlow."""

import os
import sys

import requests


def load_env(path=".env"):
    """Load environment variables from .env file."""
    env = {}
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line and "=" in line and not line.startswith("#"):
                    key, val = line.split("=", 1)
                    env[key.strip()] = val.strip()
    return env


def update_dns_records(old_ip, new_ip, api_key, api_url):
    """Update DNS records from old_ip to new_ip via hosting provider API."""
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }

    params = {"ip": old_ip}
    try:
        resp = requests.get(
            f"{api_url}/dns/records",
            headers=headers,
            params=params,
            timeout=30,
        )
        resp.raise_for_status()
        records = resp.json()
    except requests.RequestException as e:
        print(f"[dns] Error fetching records: {e}")
        return False

    updated = 0
    for record in records:
        if record.get("value") == old_ip:
            record_id = record.get("id")
            update_data = {**record, "value": new_ip}
            try:
                resp = requests.put(
                    f"{api_url}/dns/records/{record_id}",
                    headers=headers,
                    json=update_data,
                    timeout=30,
                )
                resp.raise_for_status()
                updated += 1
                print(
                    f"[dns] Updated record {record_id}: "
                    f"{old_ip} -> {new_ip}"
                )
            except requests.RequestException as e:
                print(f"[dns] Failed to update record {record_id}: {e}")

    print(f"[dns] Updated {updated} records")
    return updated > 0


def main():
    """Entry point: read args, load env, run DNS update."""
    if len(sys.argv) < 3:
        print("Usage: update_records.py <old_ip> <new_ip>")
        sys.exit(1)

    old_ip = sys.argv[1]
    new_ip = sys.argv[2]

    env = load_env()
    api_key = env.get("HOSTER_API_KEY", "")
    api_url = env.get("HOSTER_API_URL", "")

    if not api_key or not api_url:
        print(
            "[dns] ERROR: HOSTER_API_KEY and HOSTER_API_URL "
            "must be set in .env"
        )
        sys.exit(1)

    success = update_dns_records(old_ip, new_ip, api_key, api_url)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
