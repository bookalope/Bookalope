#!/usr/bin/env bash

if [ $# -ne 2 ]; then
    echo -e "Missing argument(s)\nUsage: $0 token document"
    exit 1
fi

TOKEN=$1
DOCFILE=$2
TMPDIR=$(mktemp -d)

# Make sure that the document actually exists.
if [ ! -f "$DOCFILE" ]; then
    echo "Document $DOCFILE does not exist, exiting"
    exit 1
fi

# Check that Python 3 is available.
if [ ! `builtin type -p python3` ]; then
    echo "This script requires Python 3 to be installed, exiting"
    exit 1
fi

# Check that the token has the right format.
if [[ ! $TOKEN =~ ^[0-9a-fA-F]{32}$ ]]; then
    echo "Malformed Bookalope API token, exiting"
    exit 1
fi

# The Bookalope server.
APIHOST="https://bookflow.bookalope.net"
echo "Talking to server $APIHOST"

# Separate path, filename, and extension of the document.
DOCPATH=$(dirname "$DOCFILE")
DOCNAME=$(basename "$DOCFILE")
DOCBASE="${DOCNAME%.*}"

if [ `builtin type -p http` ]; then

    # Check that the token authenticates correctly.
    if [ ! `http --headers --auth $TOKEN: GET $APIHOST/api/profile | grep HTTP | cut -d ' ' -f 2` == "200" ]; then
        echo "Wrong Bookalope API token, exiting"
        exit 1
    fi

    # Create a new book.
    echo "Creating new Book..."
    BOOKID=`http --json --print=b --auth $TOKEN: POST $APIHOST/api/books name="$DOCBASE" | python3 -c "import json,sys;obj=json.load(sys.stdin);print(obj['book']['id']);"`
    echo "Done, id=$BOOKID"

    # Create a new bookflow "Bookflow 1" for the book.
    echo "Creating new Bookflow..."
    BOOKFLOWID=`http --json --print=b --auth $TOKEN: POST $APIHOST/api/books/$BOOKID/bookflows name="Bookflow 1" title="$DOCBASE" | python3 -c "import json,sys;obj=json.load(sys.stdin);print(obj['bookflow']['id']);"`
    echo "Done, id=$BOOKFLOWID"

    # Upload the manuscript which automatically converts it using defaults.
    echo "Uploading and analyzing book document..."
    base64 "$DOCFILE" > "$TMPDIR/$DOCNAME.base64"
    http --json --auth $TOKEN: POST $APIHOST/api/bookflows/$BOOKFLOWID/files/document file=@"$TMPDIR/$DOCNAME.base64" filename="$DOCNAME" filetype=doc

    # Wait until the bookflow's step changes from 'processing' to 'convert'.
    echo "Waiting for bookflow to finish..."
    while [ 1 ]; do
        sleep 5
        STEP=`http --json --print=b --auth $TOKEN: GET $APIHOST/api/bookflows/$BOOKFLOWID | python3 -c "import json,sys;obj=json.load(sys.stdin);print(obj['bookflow']['step']);"`
        if [ "$STEP" = "convert" ]; then
            break
        fi
        if [ "$STEP" = "processing_failed" ]; then
            echo "Bookalope failed to analyze the document, exiting"
            exit 1
        fi
    done
    echo "Done"

    # Convert and download the books in a parallel batch.
    # Regarding < /dev/tty see: https://github.com/jakubroztocil/httpie/issues/150#issuecomment-21419373
    echo "Converting and downloading books..."
    function convert_book {
        DOWNLOAD_URL=`http --auth $TOKEN: POST $APIHOST/api/bookflows/$BOOKFLOWID/convert format=$1 version=test < /dev/tty | python3 -c "import json,sys;obj=json.load(sys.stdin);print(obj['download_url'])"`
        while [ 1 ]; do
            sleep 5
            STATUS=`http --auth $TOKEN: GET $DOWNLOAD_URL/status < /dev/tty | python3 -c "import json,sys;obj=json.load(sys.stdin);print(obj['status']);"`
            case "$STATUS" in
            "processing")
                ;;
            "failed")
                echo "Bookalope failed to convert the book, exiting"
                exit 1
                ;;
            "ok")
                break
                ;;
            esac
        done
        http --download --auth $TOKEN: GET $DOWNLOAD_URL > /dev/tty
    }
    export -f convert_book
    export TOKEN
    export APIHOST
    export BOOKFLOWID
    parallel --env TOKEN --env APIHOST --env BOOKFLOWID ::: "convert_book \"epub\"" "convert_book \"epub3\"" "convert_book \"mobi\"" "convert_book \"pdf\"" "convert_book \"icml\"" "convert_book \"docx\"" "convert_book \"docbook\"" "convert_book \"htmlbook\""
    echo "Done"

    # Delete the book and all of its bookflows.
    echo "Deleting book and bookflows..."
    http --auth $TOKEN: DELETE $APIHOST/api/books/$BOOKID
    echo "Done"

else

    if [ `builtin type -p curl` ]; then

        # Check that the token authenticates correctly.
        if [ ! `curl --user $TOKEN: --request GET -s -D - -o /dev/null $APIHOST/api/profile | grep HTTP | cut -d ' ' -f 2` == "200" ]; then
            echo "Wrong Bookalope API token, exiting"
            exit 1
        fi

        # Create a new book.
        echo "Creating new Book..."
        BOOKID=`curl --user $TOKEN: --header "Content-Type: application/json" --data '{"name":"'$DOCBASE'"}' --request POST $APIHOST/api/books | python3 -c "import json,sys;obj=json.load(sys.stdin);print(obj['book']['id']);"`
        echo "Done, id=$BOOKID"

        # Create a new bookflow "Bookflow 1" for the book.
        echo "Creating new Bookflow..."
        BOOKFLOWID=`curl --user $TOKEN: --header "Content-Type: application/json" --data '{"name":"Bookflow 1", "title":"'$DOCBASE'"}' --request POST $APIHOST/api/books/$BOOKID/bookflows | python3 -c "import json,sys;obj=json.load(sys.stdin);print(obj['bookflow']['id']);"`
        echo "Done, id=$BOOKFLOWID"

        # Upload the manuscript which automatically converts it using defaults.
        echo "Uploading and analyzing book document..."
        echo '{"filetype":"doc", "filename":"'$DOCNAME'", "file":"' > "$TMPDIR/$DOCNAME.json"
        base64 "$DOCFILE" >> "$TMPDIR/$DOCNAME.json"
        echo '"}' >> "$TMPDIR/$DOCNAME.json"
        curl --user $TOKEN: --header "Content-Type: application/json" --data @"$TMPDIR/$DOCNAME.json" --request POST $APIHOST/api/bookflows/$BOOKFLOWID/files/document
        echo "Done"

        # Wait until the bookflow's step changes from 'processing' to 'convert'.
        echo "Waiting for bookflow to finish..."
        while [ 1 ]; do
            sleep 5
            STEP=`curl --user $TOKEN: --header "Content-Type: application/json" --request GET $APIHOST/api/bookflows/$BOOKFLOWID | python3 -c "import json,sys;obj=json.load(sys.stdin);print(obj['bookflow']['step']);"`
            if [ "$STEP" = "convert" ]; then
                break
            fi
            if [ "$STEP" = "processing_failed" ]; then
                echo "Bookalope failed to analyze the document, exiting"
                exit 1
            fi
        done
        echo "Done"

        # Convert and download the books in a parallel batch.
        # Regarding < /dev/tty see: https://github.com/jakubroztocil/httpie/issues/150#issuecomment-21419373
        echo "Converting and downloading books..."
        function convert_book {
            DOWNLOAD_URL=`curl --user $TOKEN: --header "Content-Type: application/json" --data '{"format":"'$1'", "version":"test"}' --request POST $APIHOST/api/bookflows/$BOOKFLOWID/convert < /dev/tty | python3 -c "import json,sys;obj=json.load(sys.stdin);print(obj['download_url'])"`
            while [ 1 ]; do
                sleep 5
                STATUS=`curl --user $TOKEN: --header "Content-Type: application/json" --request GET $DOWNLOAD_URL/status < /dev/tty | python3 -c "import json,sys;obj=json.load(sys.stdin);print(obj['status']);"`
                case "$STATUS" in
                "processing")
                    ;;
                "failed")
                    echo "Bookalope failed to convert the book, exiting"
                    exit 1
                    ;;
                "ok")
                    break
                    ;;
                esac
            done
            curl --user $TOKEN: --remote-name --remote-header-name --request GET $DOWNLOAD_URL > /dev/tty
        }
        export -f convert_book
        export TOKEN
        export APIHOST
        export BOOKFLOWID
        parallel --env TOKEN --env APIHOST --env BOOKFLOWID ::: "convert_book \"epub\"" "convert_book \"epub3\"" "convert_book \"mobi\"" "convert_book \"pdf\"" "convert_book \"icml\"" "convert_book \"docx\"" "convert_book \"docbook\"" "convert_book \"htmlbook\""
        echo "Done"

        # Delete the book and all of its bookflows.
        echo "Deleting book and bookflows..."
        curl --user $TOKEN: --request DELETE $APIHOST/api/books/$BOOKID
        echo "Done"

    else
        echo "Unable to find http or curl command, exiting"
        exit 1
    fi
fi
rm -fr $TMPDIR
exit 0
