#!/bin/bash

function help() {
    echo
    echo "Usage: $0 [-s(hort)] <ticket>";
    echo "  show ticket contents in json format (all fields by default)"
    echo
    echo "Usage: $0 [-d(esc)|-i(incident description)] <ticket>";
    echo "  show ticket subject (-d) or full description (-i) in raw text"
    echo
    echo "Usage: $0 -m <ticket> [ticket ...]";
    echo "  show description for multiple tickets (slow)"
    echo
    echo "Usage: $0 -a <AssigneeName>";
    echo "  show all tickets assigned to AssigneeName (even slower!)"
    echo
    exit 1;
}

if [ "$1" = '-h' ]; then help; fi
if [ "$1" = '-s' ]; then details=short; shift; fi
if [ "$1" = '-d' ]; then details=desc; shift; fi
if [ "$1" = '-i' ]; then details=idesc; shift; fi
if [ "$1" = '-a' ]; then details=assignee; shift; fi
if [ "$1" = '-m' ]; then details=multi; shift; fi

if [ -z "$1" ]; then
    help
fi

if ! which jq >/dev/null 2>&1; then
    echo "ERROR: 'jq' is required to parse json."
    echo "You can install it with 'dnf install jq' (Fedora)"
    exit 1
fi

baseurl=http://www.dcim.cc.cec.eu.int/smt
if [ -n "$TEST_ENV" ]; then
    baseurl=http://unicons-t.cc.cec.eu.int:8991/restwssmt
fi
query=GetIncidentDetails/IncidentId/$1

case $details in
    short)
        filter=".instance | {BriefDescription, IncidentDescription, JournalUpdates}" ;;
    desc)
        jq_opt='-r'
        filter='.instance | .BriefDescription' ;;
    idesc)
        jq_opt='-r'
        filter='.instance | .IncidentDescription.IncidentDescription | join("\n")' ;;
    assignee)
        filter="."
        query="GetIncidentsSummary?AssigneeName=$1"
        ;;
    multi)
        # show "IMxxxxxxx - description" for multiple tickets (useful for reports)"
        for t in $@; do
            echo -n "$t - "
            # call itself to get a single ticket description:
            $0 -d $t
        done
        exit
        ;;
    *)
        filter=".instance | ." ;;
        # to join lines, add -r and: | join("\n")
esac

exec curl --noproxy "*" -s "$baseurl/$query" | jq $jq_opt "$filter"

