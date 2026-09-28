#!/usr/bin/env python3
"""
wiki-stream: Real-time worldwide Wikipedia live edit and headline stream in your terminal.
"""

import sys
import os
import re
import json
import signal
import argparse
import urllib.request

# ANSI Colors
C_RESET = "\033[0m"
C_BOLD = "\033[1m"
C_DIM = "\033[2m"
C_YELLOW = "\033[38;2;246;144;116m"
C_CYAN = "\033[38;2;135;206;250m"
C_GREEN = "\033[38;2;142;177;108m"
C_MAGENTA = "\033[38;2;225;99;158m"
C_BLUE = "\033[38;2;113;67;136m"


def main():
    parser = argparse.ArgumentParser(description="Real-time Wikipedia live edits stream")
    parser.add_argument("--lang", "-l", type=str, default=None, help="Filter by language/domain (e.g. 'ru', 'en', 'commons')")
    parser.add_argument("--no-bots", "-n", action="store_true", help="Filter out automated bot edits (show only human edits)")
    args = parser.parse_args()

    def handle_sigint(*_):
        sys.stdout.write(f"\n{C_DIM}Stream stopped.{C_RESET}\n")
        sys.exit(0)

    signal.signal(signal.SIGINT, handle_sigint)

    url = "https://stream.wikimedia.org/v2/stream/recentchange"
    headers = {"User-Agent": "WikiLiveStream/1.0 (ArchLinux/User)"}

    sys.stdout.write(f"{C_BOLD}{C_GREEN}⚡ Connecting to Wikimedia Global Live Stream...{C_RESET}\n\n")
    sys.stdout.flush()

    try:
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req) as resp:
            for raw_line in resp:
                line = raw_line.decode("utf-8", errors="ignore").strip()
                if not line.startswith("data: "):
                    continue

                data_str = line[6:]
                try:
                    item = json.loads(data_str)
                except Exception:
                    continue

                is_bot = item.get("bot", False)
                if args.no_bots and is_bot:
                    continue

                server_name = item.get("server_name", "wiki")
                if args.lang and args.lang.lower() not in server_name.lower():
                    continue

                title = item.get("title", "").strip()
                if not title:
                    continue

                user = item.get("user", "anon")
                comment = item.get("comment", "").strip()
                # Clean HTML tags from comment
                comment = re.sub(r"<[^>]+>", "", comment)
                comment = re.sub(r"\[\[(.*?)\]\]", r"\1", comment)

                # Color-code based on type of wiki
                if "ru." in server_name:
                    badge_color = C_GREEN
                elif "en." in server_name:
                    badge_color = C_CYAN
                elif "commons." in server_name:
                    badge_color = C_YELLOW
                else:
                    badge_color = C_MAGENTA

                bot_tag = f"{C_DIM}[BOT]{C_RESET} " if is_bot else ""
                comment_part = f" {C_DIM}— {comment[:120]}{C_RESET}" if comment else ""

                output = f"{badge_color}[{server_name}]{C_RESET} {bot_tag}{C_BOLD}{title}{C_RESET} {C_DIM}(by {user}){C_RESET}{comment_part}\n"
                sys.stdout.write(output)
                sys.stdout.flush()

    except Exception as e:
        sys.stderr.write(f"\n{C_YELLOW}Connection error: {e}{C_RESET}\n")


if __name__ == "__main__":
    main()
