#!/bin/bash

testdir="$1"
solr="$2"

T="/tmp/$USER-$$"
mkdir $T
trap "rm -rf $T" EXIT

function check_response() {
    if [ "$(jq -r .responseHeader.status $T/response.json)" != 0 ]; then
        echo "$*" >&2
        cat $T/response.json >&2
        exit 1
    fi
}

for testfile in "$testdir"/*.json; do
    testname="${testfile:${#testdir}+1:-5}"
    echo "running test: $testname"
    curl -s "$solr/update?stream.body=<delete><query>*:*</query></delete>&commit=true&wt=json" > $T/response.json
    check_response "Could not clean SolR"
    curl -s -H "Content-Type: application/json" -d @<( jq .docs "$testfile" ) "$solr/update?commit=true&wt=json" > $T/response.json
    check_response "Could not load document into SolR"
    last=$(jq '.tests | length - 1' "${testfile}")
    for i in $(seq 0 $last); do
        echo " | $(jq -r ".tests[$i].title" "${testfile}")"

        query=$(jq -r ".tests[$i].query | @uri" "${testfile}")
        curl -s -H "Content-Type: application/json" "$solr/select?q=$query&rows=100&wt=json" > $T/response.json
        check_response "Could not query SolR"

        jq -r ".tests[$i].expected[]" "${testfile}" | sort > $T/expected.lst
        jq -r ".response.docs[] | .id" "$T/response.json" | sort > $T/actual.lst
        if ! cmp -s $T/expected.lst $T/actual.lst; then
            echo "FAILED:" >&2
            diff -U 10000 -u $T/expected.lst $T/actual.lst | sed 1,3d >&2
            exit 1
        fi
    done
done