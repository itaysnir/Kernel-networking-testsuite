
for _ in $(seq "$1"); do
	./watch.pl 2> /dev/null | grep -i "tx total"
	sleep 1
done


