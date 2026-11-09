#!/bin/sh
# Lance les tests sans fenêtre : chaque scène de test (tests/sandbox_*.tscn), les traductions, puis le test réseau.
# Usage :
#   sh tests/tools/run_tests.sh                 # tout (à faire avant de fusionner une branche)
#   sh tests/tools/run_tests.sh walk fall       # seulement les scènes dont le nom contient « walk » ou « fall »
#   sh tests/tools/run_tests.sh reseau          # seulement le test réseau
#   sh tests/tools/run_tests.sh --sans-reseau   # tout sauf le test réseau
#   sh tests/tools/run_tests.sh --lent          # en temps réel, un test après l'autre (pour chercher un souci de timing)
# GODOT_PATH doit pointer vers Godot 4.7.2.
#
# Pour aller vite : les tests tournent en temps accéléré (`--fixed-fps 60` : sans fenêtre, le jeu calcule
# ses images aussi vite que possible, une image = 1/60 s de jeu) et plusieurs à la fois.
# Une scène échoue si elle plante, affiche une erreur de script, une « [test] ÉCHEC », ou dépasse le temps.
# Journaux complets dans build/tests/<scène>.log. Sortie : « TOUS LES TESTS OK » ou la liste des échecs.
cd "$(dirname "$0")/../.." || exit 2
mkdir -p build/tests
rm -f build/tests/*.result

FAST="--fixed-fps 60"
JOBS=4
NET=1
FILTERS=""
for arg in "$@"; do
	case "$arg" in
		--lent) FAST=""; JOBS=1 ;;
		--sans-reseau) NET=0 ;;
		reseau) FILTERS="$FILTERS __aucune_scene__" ;;
		*) FILTERS="$FILTERS $arg" ;;
	esac
done
# Des filtres sans « reseau » : pas de test réseau (sauf si on le demande en plus).
if [ -n "$FILTERS" ]; then
	case " $* " in
		*" reseau "*) ;;
		*) NET=0 ;;
	esac
fi
export FAST

# Scènes purement visuelles (rien de scripté) : on vérifie seulement qu'elles se lancent sans erreur.
VISUAL="sandbox_dwarf_anim sandbox_emotes sandbox_interaction"

start=$(date +%s)

# Le test réseau est le plus long : il part en premier, en parallèle des scènes.
if [ $NET -eq 1 ]; then
	(sh tests/tools/net_test.sh > build/tests/net_test.log 2>&1; echo $? > build/tests/net_test.result) &
fi

# Une scène : lancée sans fenêtre, résultat écrit dans build/tests/<scène>.result (vide = OK).
run_scene() {
	scene=$1
	name=$(basename "$scene" .tscn)
	log="build/tests/$name.log"
	case " $VISUAL " in
		*" $name "*) extra="--quit-after 120" ;;
		*) extra="" ;;
	esac
	timeout 180 "$GODOT_PATH" --headless $FAST --path . "res://$scene" $extra -- --auto > "$log" 2>&1
	code=$?
	# Bruit connu sans fenêtre ni Steam : ignoré.
	errors=$(grep -E "SCRIPT ERROR|^ERROR|\[test\] ÉCHEC" "$log" \
		| grep -v -E "Not supported by this display server|Steam|getSteamID" | head -5)
	if [ $code -ne 0 ] || [ -n "$errors" ]; then
		{ echo "ÉCHEC  $name (code $code)"; [ -n "$errors" ] && echo "$errors" | sed 's/^/        /'; } > "build/tests/$name.result"
	else
		echo "OK     $name" > "build/tests/$name.result"
	fi
}

pids=""
for scene in tests/sandbox_*.tscn; do
	name=$(basename "$scene" .tscn)
	if [ -n "$FILTERS" ]; then
		keep=0
		for f in $FILTERS; do
			case "$name" in *"$f"*) keep=1 ;; esac
		done
		[ $keep -eq 0 ] && continue
	fi
	run_scene "$scene" &
	pids="$pids $!"
	# Pas plus de JOBS scènes à la fois : on attend la plus ancienne avant d'en lancer une autre.
	set -- $pids
	if [ $# -ge $JOBS ]; then
		wait "$1" 2>/dev/null
		shift
		pids="$*"
	fi
done

if [ -z "$FILTERS" ]; then
	(if timeout 60 "$GODOT_PATH" --headless --path . -s res://tests/tools/check_translations.gd > build/tests/translations.log 2>&1; then
		echo "OK     traductions" > build/tests/translations.result
	else
		{ echo "ÉCHEC  traductions"; grep "ÉCHEC" build/tests/translations.log | sed 's/^/        /'; } > build/tests/translations.result
	fi) &
fi

wait

failed=""
for result in build/tests/*.result; do
	[ -f "$result" ] || continue
	name=$(basename "$result" .result)
	if [ "$name" = "net_test" ]; then
		if [ "$(cat "$result")" = "0" ] && grep -q "NET TEST OK" build/tests/net_test.log; then
			echo "OK     net_test"
		else
			echo "ÉCHEC  net_test (voir build/net_test_host.log et build/net_test_client.log)"
			grep -E "écart|ÉCHEC|ERROR" build/tests/net_test.log | head -8 | sed 's/^/        /'
			failed="$failed net_test"
		fi
		continue
	fi
	cat "$result"
	case "$(head -1 "$result")" in ÉCHEC*) failed="$failed $name" ;; esac
done

echo "($(( $(date +%s) - start )) s)"
if [ -z "$failed" ]; then
	echo "TOUS LES TESTS OK"
	exit 0
fi
echo "ÉCHECS :$failed"
exit 1
