#!/bin/sh
# Test réseau automatique : lance un hôte et un client sans fenêtre, affiche le résultat.
# Usage : sh tests/tools/net_test.sh   (GODOT_PATH doit pointer vers Godot 4.7.2)
cd "$(dirname "$0")/../.." || exit 2
mkdir -p build
"$GODOT_PATH" --headless --path . res://tests/tools/net_test.tscn -- --role=client > build/net_test_client.log 2>&1 &
"$GODOT_PATH" --headless --path . res://tests/tools/net_test.tscn -- --role=host > build/net_test_host.log 2>&1
status=$?
wait
grep -ah "net_test\|ERROR\|SCRIPT ERROR" build/net_test_host.log build/net_test_client.log
exit $status
