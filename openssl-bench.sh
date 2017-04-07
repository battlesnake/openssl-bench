#!/bin/bash

set -u

declare -r random="$(mktemp)"

trap "rm -f -- '$random'" EXIT ERR

declare -r bs=1M
declare -r count=1k

dd if=/dev/urandom of="$random" bs="$bs" count="$count" status=none

function line {
	printf -- "%s\t" "$@"
	printf -- "\n"
}

function get_speed {
	perl -pe 's/\r\n?/\n/g;' | tail -n 1 | perl -pe 's{\[\s*(\d+(?:\.\d+)?.)i?B/s\s*\]}{$1};'
}

function bench {
	line \
		"$1" \
		"$( ( dd if=/dev/zero bs="$bs" count="$count" status=none | $2 | pv -fWaB "$bs" >/dev/null ) 2>&1 | get_speed )" \
		"$( ( dd if="$random" bs="$bs" count="$count" status=none | $2 | pv -fWaB "$bs" >/dev/null ) 2>&1 | get_speed )" \
		"$( ( dd if=/dev/zero bs="$bs" count="$count" status=none | $3 | pv -fWaB "$bs" >/dev/null ) 2>&1 | get_speed )" \
		"$( ( dd if="$random" bs="$bs" count="$count" status=none | $3 | pv -fWaB "$bs" >/dev/null ) 2>&1 | get_speed )"
}

function benchcipher {
	bench "$1" "$2 -e" "$2 -d"
}

function run {
	line 'Process' 'Encrypt zero' 'Encrypt random' 'Decrypt zero' 'Decrypt random'

	bench 'Cat' cat cat

	benchcipher 'AES-256-CBC' 'openssl enc -nopad -nosalt -aes-256-cbc -pass pass:testing'
	benchcipher 'AES-192-CBC' 'openssl enc -nopad -nosalt -aes-192-cbc -pass pass:testing'
	benchcipher 'AES-128-CBC' 'openssl enc -nopad -nosalt -aes-128-cbc -pass pass:testing'

	benchcipher 'AES-256-CTR' 'openssl enc -nopad -nosalt -aes-256-ctr -pass pass:testing'
	benchcipher 'AES-192-CTR' 'openssl enc -nopad -nosalt -aes-192-ctr -pass pass:testing'
	benchcipher 'AES-128-CTR' 'openssl enc -nopad -nosalt -aes-128-ctr -pass pass:testing'

	benchcipher 'BF-CBC' 'openssl enc -nopad -nosalt -bf-cbc -pass pass:testing'

	echo ''

	line 'OpenSSL version' "$(openssl version)"

	echo ''

	line 'Kernel' "$(uname -a)"
}

run | tee openssl-bench.log | column -ts$'\t' -o ' | '
