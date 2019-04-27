#!/usr/bin/env bash
#
# TODO - Add --verbose or --silent option.
#      - Pass a directory of ebook files, and use `parallel` (if installed) to process batches.
#      - Add --server option to pick beta or production server.

if [ $# -ne 2 ]; then
    echo -e "Upgrade and/or fix an EPUB file using the Bookalope cloud service.\nMissing argument(s)\nUsage: $0 token epub"
    exit 1
fi

TOKEN=$1
EBOOKFILE=$2
TMPDIR=$(mktemp -d)

# Make sure that the ebook file actually exists.
if [ ! -f "$EBOOKFILE" ]; then
    echo "Ebook file $EBOOKFILE does not exist, exiting"
    exit 1
fi

# Check that Python 3 is available.
if [ ! `builtin type -p python3` ]; then
    echo "This script requires Python 3 to be installed, exiting"
    exit 1
fi

# Check that the Bookalope authentication token has the right format.
if [[ ! $TOKEN =~ ^[0-9a-fA-F]{32}$ ]]; then
    echo "Malformed Bookalope API token, exiting"
    exit 1
fi

# The Bookalope server.
APIHOST="https://beta.bookalope.net"
echo "Talking to Bookalope server $APIHOST"

# Separate path, filename, and extension of the document.
EBOOKPATH=$(dirname "$EBOOKFILE")
EBOOKNAME=$(basename "$EBOOKFILE")
EBOOKBASE="${EBOOKNAME%.*}"

# Wait for a given number of seconds while showing a spinner.
function wait() {
    local COUNT=$1
    while ((COUNT--)); do
        for SPIN in '-' '\' '|' '/'; do
            echo -en "Waiting for bookflow to finish $SPIN \r"
            sleep 0.25
        done
    done
}

# Use httpie to talk to the Bookalope server.
if [ `builtin type -p http` ]; then

    # Check that the Bookalope token authenticates correctly with the server.
    if [ ! `http --headers --auth $TOKEN: GET $APIHOST/api/profile | grep HTTP | cut -d ' ' -f 2` == "200" ]; then
        echo "Wrong Bookalope API token, exiting"
        exit 1
    fi

    # Create a new book, and use the book's initial bookflow.
    echo "Creating new Book..."
    read -r BOOKID BOOKFLOWID <<< `http --json --print=b --auth $TOKEN: POST $APIHOST/api/books name="$EBOOKBASE" | python3 -c "import json,sys;obj=json.load(sys.stdin);print(obj['book']['id'], obj['book']['bookflows'][0]['id']);"`
    echo "Done, book=$BOOKID, bookflow=$BOOKFLOWID"

    # Upload the ebook file which automatically ingests its content and styling. Passing the `ignore_analysis`
    # argument here tells Bookalope to ignore the AI-assisted semantic structuring of the ebook, and instead
    # carry through the ebook's visual styles (AKA WYSIWYG conversion). The result is a flat and unstructured
    # ebook, but it is at least a valid EPUB3 file. So make sure you know what you're doing here.
    echo "Uploading and ingesting ebook..."
    base64 "$EBOOKFILE" > "$TMPDIR/$EBOOKNAME.base64"
    http --json --auth $TOKEN: POST $APIHOST/api/bookflows/$BOOKFLOWID/files/document file=@"$TMPDIR/$EBOOKNAME.base64" filename="$EBOOKNAME" filetype=epub ignore_analysis=true

    # Wait until the bookflow's step changes from 'processing' to 'convert', thus indicating that Bookalope
    # has finished noodling through the ebook.
    while true; do
        wait 5
        STEP=`http --json --print=b --auth $TOKEN: GET $APIHOST/api/bookflows/$BOOKFLOWID | python3 -c "import json,sys;obj=json.load(sys.stdin);print(obj['bookflow']['step']);"`
        if [ "$STEP" = "convert" ]; then
            break
        fi
        if [ "$STEP" = "processing_failed" ]; then
            echo "Bookalope failed to ingest the ebook, exiting"
            exit 1
        fi
    done
    echo "Waiting for bookflow to finish, done!"

    # Convert the ingested ebook file to EPUB3 and download it.
    # Regarding < /dev/tty see: https://github.com/jakubroztocil/httpie/issues/150#issuecomment-21419373
    echo "Converting and downloading EPUB3 format..."
    DOWNLOAD_URL=`http --auth $TOKEN: POST $APIHOST/api/bookflows/$BOOKFLOWID/convert format=epub3 version=final < /dev/tty | python3 -c "import json,sys;obj=json.load(sys.stdin);print(obj['download_url'])"`
    while true; do
        wait 5
        STATUS=`http --auth $TOKEN: GET $DOWNLOAD_URL/status < /dev/tty | python3 -c "import json,sys;obj=json.load(sys.stdin);print(obj['status']);"`
        case "$STATUS" in
        "processing")
            ;;
        "failed")
            echo "Bookalope failed to convert the ebook, exiting"
            exit 1
            ;;
        "ok")
            echo "Waiting for bookflow to finish, done!"
            break
            ;;
        esac
    done
    http --download --auth $TOKEN: GET $DOWNLOAD_URL > /dev/tty
    mv $BOOKFLOWID.epub "${EBOOKFILE%.*}-$BOOKFLOWID.epub"
    echo "Done"

    # Delete the book and its bookflow.
    echo "Deleting book and bookflows..."
    http --auth $TOKEN: DELETE $APIHOST/api/books/$BOOKID
    echo "Done"

else

    # Use curl to talk to the Bookalope server.
    if [ `builtin type -p curl` ]; then

        # Check that the Bookalope token authenticates correctly with the server.
        if [ ! `curl --user $TOKEN: --request GET -s -D - -o /dev/null $APIHOST/api/profile | grep HTTP | cut -d ' ' -f 2` == "200" ]; then
            echo "Wrong Bookalope API token, exiting"
            exit 1
        fi

        # Create a new book, and use the book's initial bookflow.
        echo "Creating new Book..."
        read -r BOOKID BOOKFLOWID <<< `curl --user $TOKEN: --header "Content-Type: application/json" --data '{"name":"'$EBOOKBASE'"}' --request POST $APIHOST/api/books | python3 -c "import json,sys;obj=json.load(sys.stdin);print(obj['book']['id'], obj['book']['bookflows'][0]['id']);"`
        echo "Done, book=$BOOKID, bookflow=$BOOKFLOWID"

        # Upload the ebook file which automatically ingests its content and styling. Passing the `ignore_analysis`
        # argument here tells Bookalope to ignore the AI-assisted semantic structuring of the ebook, and instead
        # carry through the ebook's visual styles (AKA WYSIWYG conversion). The result is a flat and unstructured
        # ebook, but it is at least a valid EPUB3 file. So make sure you know what you're doing here.
        echo "Uploading and ingesting ebook..."
        echo '{"filetype":"epub", "filename":"'$EBOOKNAME'", "ignore_analysis":"true", "file":"' > "$TMPDIR/$EBOOKNAME.json"
        base64 "$EBOOKFILE" >> "$TMPDIR/$EBOOKNAME.json"
        echo '"}' >> "$TMPDIR/$EBOOKNAME.json"
        curl --user $TOKEN: --header "Content-Type: application/json" --data @"$TMPDIR/$EBOOKNAME.json" --request POST $APIHOST/api/bookflows/$BOOKFLOWID/files/document
        echo "Done"

        # Wait until the bookflow's step changes from 'processing' to 'convert', thus indicating that Bookalope
        # has finished noodling through the ebook.
        while true; do
            wait 5
            STEP=`curl --user $TOKEN: --header "Content-Type: application/json" --request GET $APIHOST/api/bookflows/$BOOKFLOWID | python3 -c "import json,sys;obj=json.load(sys.stdin);print(obj['bookflow']['step']);"`
            if [ "$STEP" = "convert" ]; then
                break
            fi
            if [ "$STEP" = "processing_failed" ]; then
                echo "Bookalope failed to ingest the ebook, exiting"
                exit 1
            fi
        done
        echo "Waiting for bookflow to finish, done!"

        # Convert the ingested ebook file to EPUB3 and download it.
        # Regarding < /dev/tty see: https://github.com/jakubroztocil/httpie/issues/150#issuecomment-21419373
        echo "Converting and downloading books..."
        DOWNLOAD_URL=`curl --user $TOKEN: --header "Content-Type: application/json" --data '{"format":"epub3", "version":"final"}' --request POST $APIHOST/api/bookflows/$BOOKFLOWID/convert < /dev/tty | python3 -c "import json,sys;obj=json.load(sys.stdin);print(obj['download_url'])"`
        while true; do
            wait 5
            STATUS=`curl --user $TOKEN: --header "Content-Type: application/json" --request GET $DOWNLOAD_URL/status < /dev/tty | python3 -c "import json,sys;obj=json.load(sys.stdin);print(obj['status']);"`
            case "$STATUS" in
            "processing")
                ;;
            "failed")
                echo "Bookalope failed to convert the ebook, exiting"
                exit 1
                ;;
            "ok")
                echo "Waiting for bookflow to finish, done!"
                break
                ;;
            esac
        done
        curl --user $TOKEN: --remote-name --remote-header-name --request GET $DOWNLOAD_URL > /dev/tty
        mv $BOOKFLOWID.epub "${EBOOKFILE%.*}-$BOOKFLOWID.epub"
        echo "Done"

        # Delete the book and its bookflow.
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
