#!/usr/bin/env bash
set -u

sed -i '1,/^# KIT$/{/^# KIT$/!d}' "/home/agent/.config/opencode/AGENTS.md"

PORT=44444

# Supervisor: relaunch the server whenever it dies.
server_supervisor() {
  while true; do
    # important logs will break the TUI. redirect everything to a log file.
    opencode2 serve --hostname 0.0.0.0 --port "$PORT" >/tmp/opencode2.log 2>&1
    sleep 1
  done
}

server_supervisor &
SUPERVISOR_PID=$!

sleep 1

cleanup() {
  kill "$SUPERVISOR_PID" 2>/dev/null
  wait "$SUPERVISOR_PID" 2>/dev/null
}
trap cleanup EXIT INT TERM HUP

# opencode2 reconnects to the server automatically, so we can just run the client in the foreground.
# once we stop the client, we stop the server as well.
opencode2 --server "http://127.0.0.1:$PORT"
