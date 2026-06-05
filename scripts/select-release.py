#!/usr/bin/env python3
"""Select the latest eligible GitHub release for Homebrew formula updaters."""

import argparse
import json
import re
import shlex
import subprocess
import sys
from datetime import datetime, timezone

DEFAULT_GITHUB_HOST = "github.com"
DEFAULT_GITHUB_USER = "cavanaug"


def emit(name: str, value: str) -> None:
    print(f"{name}={shlex.quote(value)}")


def gh_message(result: subprocess.CompletedProcess[str]) -> str:
    return result.stderr.strip() or result.stdout.strip()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Select the latest non-draft, non-prerelease GitHub release "
            "that is at least the requested age."
        )
    )
    parser.add_argument("--repo", required=True, help="GitHub owner/repo")
    parser.add_argument(
        "--min-age-days",
        type=int,
        required=True,
        help="Minimum release age in days",
    )
    parser.add_argument(
        "--asset",
        action="append",
        default=[],
        metavar="VAR=NAME",
        help="Required release asset (VAR must be [A-Z][A-Z0-9_]*); repeatable",
    )
    parser.add_argument(
        "--github-host",
        default=DEFAULT_GITHUB_HOST,
        help=f"GitHub hostname for gh api (default: {DEFAULT_GITHUB_HOST})",
    )
    parser.add_argument(
        "--github-user",
        default=DEFAULT_GITHUB_USER,
        help=f"Required gh authenticated user (default: {DEFAULT_GITHUB_USER})",
    )
    return parser.parse_args()


def parse_assets(raw_assets: list[str]) -> dict[str, str]:
    assets: dict[str, str] = {}
    for item in raw_assets:
        key, _, name = item.partition("=")
        if not key or not name:
            sys.exit("--asset must be in VAR=NAME format")
        if not re.fullmatch(r"[A-Z][A-Z0-9_]*", key):
            sys.exit(f"Invalid asset variable name: {key}")
        assets[key] = name
    return assets


def run_gh(args: list[str], *, hostname: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["gh", *args, "--hostname", hostname],
        capture_output=True,
        text=True,
        check=False,
    )


def ensure_github_user(hostname: str, expected_user: str) -> None:
    result = run_gh(["api", "user", "-q", ".login"], hostname=hostname)
    if result.returncode != 0:
        sys.exit(
            f"Failed to verify gh authentication on {hostname}: {gh_message(result)}\n"
            f"Run: gh auth login --hostname {hostname}"
        )

    active_user = result.stdout.strip()
    if active_user != expected_user:
        sys.exit(
            f"gh is logged in as {active_user!r} on {hostname}, "
            f"but {expected_user!r} is required.\n"
            f"Run: gh auth switch --hostname {hostname} --user {expected_user}"
        )


def fetch_releases(repo: str, page: int, *, hostname: str) -> list[dict]:
    endpoint = f"repos/{repo}/releases?per_page=100&page={page}"
    result = run_gh(["api", endpoint], hostname=hostname)
    if result.returncode != 0:
        sys.exit(f"gh api failed for {endpoint} on {hostname}: {gh_message(result)}")

    releases = json.loads(result.stdout)
    if not isinstance(releases, list):
        sys.exit(f"Unexpected gh api response for {endpoint}")
    return releases


def select_release(
    repo: str,
    min_age_days: int,
    *,
    hostname: str,
) -> tuple[dict, int] | None:
    now = datetime.now(timezone.utc)
    page = 1

    while True:
        releases = fetch_releases(repo, page, hostname=hostname)
        if not releases:
            return None

        for candidate in releases:
            if candidate.get("draft") or candidate.get("prerelease"):
                continue

            published_at = candidate.get("published_at")
            if not published_at:
                continue

            published = datetime.fromisoformat(published_at.replace("Z", "+00:00"))
            age_days = int((now - published).total_seconds() // 86_400)
            if age_days < min_age_days:
                continue

            return candidate, age_days

        page += 1


def main() -> None:
    args = parse_args()
    required_assets = parse_assets(args.asset)

    ensure_github_user(args.github_host, args.github_user)

    selected = select_release(
        args.repo,
        args.min_age_days,
        hostname=args.github_host,
    )
    if not selected:
        emit("FOUND", "false")
        return

    selected_release, selected_age_days = selected
    assets = {
        asset["name"]: asset.get("digest", "").removeprefix("sha256:")
        for asset in selected_release.get("assets", [])
    }

    missing_assets = [
        name
        for name in required_assets.values()
        if not assets.get(name)
    ]
    if missing_assets:
        sys.exit(f"Missing release assets: {', '.join(missing_assets)}")

    tag_name = selected_release["tag_name"]
    if tag_name.startswith("v"):
        tag_name = tag_name[1:]

    emit("FOUND", "true")
    emit("LATEST", tag_name)
    emit("PUBLISHED_AT", selected_release["published_at"])
    emit("AGE_DAYS", str(selected_age_days))

    for key, name in required_assets.items():
        digest = assets[name]
        if not digest:
            sys.exit(f"Missing sha256 digest for asset: {name}")
        emit(key, digest)


if __name__ == "__main__":
    main()
