#!/usr/bin/env bash

if [ $# -ne 2 ] && [ $# -ne 3 ]; then
    echo -e "Missing argument(s)\nUsage: $0 token document [type]"
    exit 1
fi

TOKEN=$1
DOCFILE=$2
DOCTYPE=${3:-"doc"}
TMPDIR=$(mktemp -d)

# Make sure that we remove the temporary directory upon exit.
trap "rm --recursive --force $TMPDIR" exit

# Make sure that the document actually exists.
if [ ! -f "$DOCFILE" ]; then
    echo "Document $DOCFILE does not exist, exiting"
    exit 1
fi

# Make sure that the document type is one supported by Bookalope.
if [[ ! "$DOCTYPE" =~ ^(doc|epub|gutenberg)$ ]]; then
    echo "Document type '$DOCTYPE' is not one of 'doc', 'epub', 'gutenberg'"
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
echo "Talking to Bookalope server $APIHOST"

# Separate path, filename, and extension of the document.
DOCPATH=$(dirname "$DOCFILE")
DOCNAME=$(basename "$DOCFILE")
DOCBASE="${DOCNAME%.*}"

if [ `builtin type -p http` ]; then

    # Check that the token authenticates correctly.
    if [ ! `http --headers --auth $TOKEN: HEAD $APIHOST/api/profile | grep HTTP | cut -d ' ' -f 2` == "200" ]; then
        echo "Wrong Bookalope API token, exiting"
        exit 1
    fi

    # Check that the API version is correct.
    APIVER=`http --headers --auth $TOKEN: HEAD $APIHOST/api/profile | grep X-Bookalope-Api-Version | cut -d ' ' -f 2`
    if [ ! "${APIVER//[$'\t\r\n ']}" == "1.1.0" ]; then
        echo "Invalid API server version, please update this client; exiting"
        exit 1
    fi

    # Create a new book.
    echo "Creating new Book..."
    read -r BOOKID BOOKFLOWID <<< `http --ignore-stdin --json --print=b --auth $TOKEN: POST $APIHOST/api/books name="$DOCBASE" | python3 -c "import json,sys;obj=json.load(sys.stdin);print(obj['book']['id'], obj['book']['bookflows'][0]['id']);"`
    echo "Done, Book id=$BOOKID, Bookflow id=$BOOKFLOWID"

    # If we've purchased a plan through the Bookalope website, then we can now credit this
    # Bookflow, thus getting access to the full version of the book. Note that this script
    # uses Bookalope's REST API, and that requires a 'pro' credit.
    http --ignore-stdin --json --print= --auth $TOKEN: POST $APIHOST/api/bookflows/$BOOKFLOWID/credit type="pro"

    # Upload the manuscript which automatically converts it using defaults. Note that the
    # `filetype` parameter here is optional; if unspecified then the Bookalope server will
    # attempt to determine the type of the uploaded file, and how to handle it.
    echo "Uploading and analyzing document: $DOCNAME"
    base64 "$DOCFILE" > "$TMPDIR/$DOCNAME.base64"
    http --ignore-stdin --json --print= --auth $TOKEN: POST $APIHOST/api/bookflows/$BOOKFLOWID/files/document file=@"$TMPDIR/$DOCNAME.base64" filename="$DOCNAME" filetype="$DOCTYPE"

    # Wait until the bookflow's step changes from 'processing' to 'convert'.
    echo "Waiting for Bookflow to finish..."
    while true; do
        sleep 5
        STEP=`http --ignore-stdin --json --print=b --auth $TOKEN: GET $APIHOST/api/bookflows/$BOOKFLOWID | python3 -c "import json,sys;obj=json.load(sys.stdin);print(obj['bookflow']['step']);"`
        if [ "$STEP" = "convert" ]; then
            echo "Done"
            break
        fi
        if [ "$STEP" = "processing_failed" ]; then
            echo "Bookalope failed to analyze the document, exiting"
            exit 1
        fi
    done

    # Convert and download the books in a parallel batch.
    # Regarding < /dev/tty see: https://github.com/jakubroztocil/httpie/issues/150#issuecomment-21419373
    echo "Converting and downloading books..."
    function convert_book {
        local DOWNLOAD_URL=`http --ignore-stdin --print=b --auth $TOKEN: POST $APIHOST/api/bookflows/$BOOKFLOWID/convert format=$1 style=default < /dev/tty | python3 -c "import json,sys;obj=json.load(sys.stdin);print(obj['download_url'])"`
        while true; do
            sleep 5
            STATUS=`http --ignore-stdin --print=b --auth $TOKEN: GET $DOWNLOAD_URL/status < /dev/tty | python3 -c "import json,sys;obj=json.load(sys.stdin);print(obj['status']);"`
            case "$STATUS" in
            "processing")
                ;;
            "failed")
                echo "Bookalope failed to convert the book to $1, skipping"
                break
                ;;
            "available")
                http --download --ignore-stdin --print= --auth $TOKEN: GET $DOWNLOAD_URL > /dev/tty
                break
                ;;
            esac
        done
    }
    export -f convert_book
    export TOKEN
    export APIHOST
    export BOOKFLOWID
    parallel --env TOKEN --env APIHOST --env BOOKFLOWID ::: "convert_book \"epub\"" "convert_book \"epub3\"" "convert_book \"mobi\"" "convert_book \"pdf\"" "convert_book \"icml\"" "convert_book \"docx\"" "convert_book \"docbook\"" "convert_book \"htmlbook\""
    echo "Done"

    # Delete the book and all of its bookflows.
    echo "Deleting Book and Bookflows..."
    http --ignore-stdin --print= --auth $TOKEN: DELETE $APIHOST/api/books/$BOOKID
    echo "Done"

else

    if [ `builtin type -p curl` ]; then

        # Check that the token authenticates correctly.
        if [ ! `curl --silent --show-error --user $TOKEN: --request HEAD -s -D - -o /dev/null $APIHOST/api/profile | grep HTTP | cut -d ' ' -f 2` == "200" ]; then
            echo "Wrong Bookalope API token, exiting"
            exit 1
        fi

        # Check that the API version is correct.
        APIVER=`curl --silent --show-error --user $TOKEN: --request HEAD -s -D - -o /dev/null $APIHOST/api/profile | grep X-Bookalope-Api-Version | cut -d ' ' -f 2`
        if [ ! "${APIVER//[$'\t\r\n ']}" == "1.1.0" ]; then
            echo "Invalid API server version, please update this client; exiting"
            exit 1
        fi

        # Create a new book.
        echo "Creating new Book..."
        read -r BOOKID BOOKFLOWID <<< `curl --silent --show-error --user $TOKEN: --header "Content-Type: application/json" --data '{"name":"'$DOCBASE'"}' --request POST $APIHOST/api/books | python3 -c "import json,sys;obj=json.load(sys.stdin);print(obj['book']['id'], obj['book']['bookflows'][0]['id']);"`
        echo "Done, Book id=$BOOKID, Bookflow id=$BOOKFLOWID"

        # If we've purchased a plan through the Bookalope website, then we can now credit this
        # Bookflow, thus getting access to the full version of the book. Note that this script
        # uses Bookalope's REST API, and that requires a 'pro' credit.
        echo '{"type":"pro"}' > "$TMPDIR/$DOCNAME.json"  # Or "basic", depending on the plan.
        curl --silent --show-error -output /dev/null --user $TOKEN: --header "Content-Type: application/json" --data @"$TMPDIR/$DOCNAME.json" --request POST $APIHOST/api/bookflows/$BOOKFLOWID/credit

        # Upload the manuscript which automatically converts it using defaults.
        echo "Uploading and analyzing book document..."
        echo '{"filetype":"'$DOCTYPE'", "filename":"'$DOCNAME'", "file":"' > "$TMPDIR/$DOCNAME.json"
        base64 "$DOCFILE" >> "$TMPDIR/$DOCNAME.json"
        echo '"}' >> "$TMPDIR/$DOCNAME.json"
        curl --silent --show-error -output /dev/null --user $TOKEN: --header "Content-Type: application/json" --data @"$TMPDIR/$DOCNAME.json" --request POST $APIHOST/api/bookflows/$BOOKFLOWID/files/document

        # Wait until the bookflow's step changes from 'processing' to 'convert'.
        echo "Waiting for Bookflow to finish..."
        while true; do
            sleep 5
            STEP=`curl --silent --show-error --user $TOKEN: --header "Content-Type: application/json" --request GET $APIHOST/api/bookflows/$BOOKFLOWID | python3 -c "import json,sys;obj=json.load(sys.stdin);print(obj['bookflow']['step']);"`
            if [ "$STEP" = "convert" ]; then
                echo "Done"
                break
            fi
            if [ "$STEP" = "processing_failed" ]; then
                echo "Bookalope failed to analyze the document, exiting"
                exit 1
            fi
        done

        # Convert and download the books in a parallel batch.
        # Regarding < /dev/tty see: https://github.com/jakubroztocil/httpie/issues/150#issuecomment-21419373
        echo "Converting and downloading books..."
        function convert_book {
            local DOWNLOAD_URL=`curl --silent --show-error --user $TOKEN: --header "Content-Type: application/json" --data '{"format":"'$1'", "style":"default"}' --request POST $APIHOST/api/bookflows/$BOOKFLOWID/convert < /dev/tty | python3 -c "import json,sys;obj=json.load(sys.stdin);print(obj['download_url'])"`
            while true; do
                sleep 5
                STATUS=`curl --silent --show-error --user $TOKEN: --header "Content-Type: application/json" --request GET $DOWNLOAD_URL/status < /dev/tty | python3 -c "import json,sys;obj=json.load(sys.stdin);print(obj['status']);"`
                case "$STATUS" in
                "processing")
                    ;;
                "failed")
                    echo "Bookalope failed to convert the book to $1, skipping"
                    break
                    ;;
                "available")
                    curl --silent --show-error --user $TOKEN: --remote-name --remote-header-name --request GET $DOWNLOAD_URL > /dev/tty
                    break
                    ;;
                esac
            done
        }
        export -f convert_book
        export TOKEN
        export APIHOST
        export BOOKFLOWID
        # Unlike with `http` we do not request EPUB2 from the Bookalope server because curl does not
        # handle existing files well: "epub" and "epub3" produce the same local file name.
        parallel --env TOKEN --env APIHOST --env BOOKFLOWID ::: "convert_book \"epub3\"" "convert_book \"mobi\"" "convert_book \"pdf\"" "convert_book \"icml\"" "convert_book \"docx\"" "convert_book \"docbook\"" "convert_book \"htmlbook\""
        echo "Done"

        # Delete the book and all of its bookflows.
        echo "Deleting Book and Bookflows..."
        curl --silent --show-error --user $TOKEN: --request DELETE $APIHOST/api/books/$BOOKID
        echo "Done"

    else
        echo "Unable to find http or curl command, exiting"
        exit 1
    fi
fi
exit 0
