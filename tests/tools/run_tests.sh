#!/bin/sh
# Lance tous les tests sans fenêtre : le test réseau, puis chaque scène de test (tests/sandbox_*.tscn).
# Usage : sh tests/tools/run_tests.sh   (GODOT_PATH doit pointer vers Godot 4.7.2)
# Une scène échoue si elle plante, affiche une erreur de script, une « [test] ÉCHEC », ou dépasse le temps.
# Journaux complets dans build/tests/<scène>.log. Sortie : « TOUS LES TESTS OK » ou la liste des échecs.
cd "$(dirname "$0")/../.." || exit 2
mkdir -p build/tests
failed=""

# Scènes purement visuelles (rien de scripté) : on vérifie seulement qu'elles se lancent sans erreur.
VISUAL="sandbox_dwarf_anim sandbox_emotes sandbox_interaction"

for scene in tests/sandbox_*.tscn; do
	name=$(basename "$scene" .tscn)
	log="build/tests/$name.log"
	case " $VISUAL " in
		*" $name "*) extra="--quit-after 120" ;;
		*) extra="" ;;
	esac
	timeout 180 "$GODOT_PATH" --headless --path . "res://$scene" $extra -- --auto > "$log" 2>&1
	code=$?
	# Bruit connu sans fenêtre ni Steam : ignoré.
	errors=$(grep -E "SCRIPT ERROR|^ERROR|\[test\] ÉCHEC" "$log" \
		| grep -v -E "Not supported by this display server|Steam|getSteamID" | head -5)
	if [ $code -ne 0 ] || [ -n "$errors" ]; then
		echo "ÉCHEC  $name (code $code)"
		[ -n "$errors" ] && echo "$errors" | sed 's/^/        /'
		failed="$failed $name"
	else
		echo "OK     $name"
	fi
done

echo "--- test réseau"
if sh tests/tools/net_test.sh | grep -q "NET TEST OK"; then
	echo "OK     net_test"
else
	echo "ÉCHEC  net_test (voir build/net_test_host.log et build/net_test_client.log)"
	failed="$failed net_test"
fi

if [ -z "$failed" ]; then
	echo "TOUS LES TESTS OK"
	exit 0
fi
echo "ÉCHECS :$failed"
exit 1
