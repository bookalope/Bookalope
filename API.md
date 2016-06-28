<img src="https://bookalope.net/img/bookalope-logo.png" width="50%" alt="Bookalope Logo">

## The Bookalope REST API

### Overview

[Bookalope](https://bookalope.net/) provides web services to the user through a [REST API](https://en.wikipedia.org/wiki/Representational_state_transfer). All resource URLs are based on `https://bookflow.bookalope.net/api` and require [basic authenticated client access](https://en.wikipedia.org/wiki/Basic_access_authentication) with each request.

When a user logs into Bookalope through the website, a session and an API token are generated. This API token can be found on the user's profile page, and is used to authenticate the REST requests. The token is valid for as long as the user's account exists, and can be changed any time.

Since basic authentication requires a Base64 encoded username and password, the token is passed as the username and the password is empty, i.e.:

    username = token
    password = ""
    auth_string = base64_encode(username + ":" + password)

For `GET` requests, parameters are passed as part of the URL. For `POST` requests, all parameters and return values are passed as a JSON body.

Upon successful execution of a request, the return code of a response is one of the [2xx success codes](https://en.wikipedia.org/wiki/List_of_HTTP_status_codes#2xx_Success). Failure is signaled through the appropriate return code in the [4xx client error](https://en.wikipedia.org/wiki/List_of_HTTP_status_codes#4xx_Client_Error) or [5xx server error](https://en.wikipedia.org/wiki/List_of_HTTP_status_codes#5xx_Server_Error) ranges, in which case the response body usually contains a JSON string describing the cause of the failure. The JSON error string has the following format:

    {
        "errors": [
            {
                "description": "...",
                "location": "...",
                "name": "..."
            }
        ],
        "status": "error"
    }

Versioning of the API is currently not considered; options are using the URL or by extending the `Accept` request entry.

### User Profile

`GET https://bookflow.bookalope.net/api/profile` 

Get the current profile data.

**Parameters**: n/a  
**Return**: first and last name  
**Errors**: n/a

    ~ > http --auth token: --verbose GET https://bookflow.bookalope.net/api/profile
    GET /api/profile HTTP/1.1
    Accept: application/json
    Accept-Encoding: gzip, deflate
    Authorization: Basic token
    Connection: keep-alive
    Content-Type: application/json
    Host: bookflow.bookalope.net
    User-Agent: HTTPie/0.9.2
    
    HTTP/1.1 200 OK
    Content-Length: 58
    Content-Type: application/json; charset=UTF-8
    Date: Fri, 18 Sep 2015 06:57:16 GMT
    Server: nginx/1.9.4
    
    {
        "user": {
            "firstname": "Jens",
            "lastname": "Tröger"
        }
    }

`POST https://bookflow.bookalope.net/api/profile`

Modify the current profile data.

**Parameters**: `firstname` (string) and `lastname` (string)  
**Return**: n/a  
**Errors**: n/a

    ~ > http --auth token: --json --verbose POST https://bookflow.bookalope.net/api/profile firstname="Jens" lastname="Troeger"
    POST /api/profile HTTP/1.1
    Accept: application/json
    Accept-Encoding: gzip, deflate
    Authorization: Basic token
    Connection: keep-alive
    Content-Length: 44
    Content-Type: application/json
    Host: bookflow.bookalope.net
    User-Agent: HTTPie/0.9.2
    
    {
        "firstname": "Jens",
        "lastname": "Troeger"
    }
    
    HTTP/1.1 200 OK
    Content-Length: 0
    Content-Type: text/html; charset=UTF-8
    Date: Fri, 18 Sep 2015 06:58:53 GMT
    Server: nginx/1.9.4

### Books

`GET https://bookflow.bookalope.net/api/books`

Get the list of book ids for the current profile.

**Parameters**: n/a  
**Return**: List of books and their details.  
**Errors**: n/a  

    ~ > http --auth token: --verbose GET https://bookflow.bookalope.net/api/books
    GET /api/books HTTP/1.1
    Accept: application/json
    Accept-Encoding: gzip, deflate
    Authorization: Basic token
    Connection: keep-alive
    Content-Type: application/json
    Host: bookflow.bookalope.net
    User-Agent: HTTPie/0.9.2
    
    HTTP/1.1 200 OK
    Content-Length: 1115
    Content-Type: application/json; charset=UTF-8
    Date: Fri, 18 Sep 2015 17:30:42 GMT
    Server: nginx/1.9.4
    
    {
        "books": [
            {
                "bookflows": [
                    {
                        "id": "143b2a9e7c844d1281a1e593c7b10248",
                        "name": "Bookflow 1"
                    },
                    {
                        "id": "a469de3069dd4b9ca58b425352107310",
                        "name": "Bookflow 2"
                    }
                ],
                "created": "2015-09-16T00:06:41",
                "id": "f99f21dd598840d5b7caf9bf39a51b00",
                "name": "Bla Test"
            }
        ]
    }

`POST https://bookflow.bookalope.net/api/books`

Create a new book with a single empty bookflow.

**Parameters**: `name` (string) is the title for the new book  
**Return**: Information about the new book.  
**Errors**: n/a

    ~ > http --auth token: --json --verbose POST https://bookflow.bookalope.net/api/books name="Great New Book"
    POST /api/books HTTP/1.1
    Accept: application/json
    Accept-Encoding: gzip, deflate
    Authorization: Basic token
    Connection: keep-alive
    Content-Length: 26
    Content-Type: application/json
    Host: bookflow.bookalope.net
    User-Agent: HTTPie/0.9.2
    
    {
        "name": "Great New Book"
    }
    
    HTTP/1.1 201 Created
    Content-Length: 170
    Content-Type: application/json; charset=UTF-8
    Date: Fri, 18 Sep 2015 17:34:16 GMT
    Server: nginx/1.9.4
    
    {
        "book": {
            "bookflows": [
                {
                    "id": "ce1cebb526df44f5930cef992cd9d396",
                    "name": null
                }
            ],
            "created": "2015-09-18T17:34:16.661944",
            "id": "29fdc01dddb345268400bebef45b9d9e",
            "name": "Great New Book"
        }
    }

`GET https://bookflow.bookalope.net/api/books/{book_id}`

Get the metadata (id, name, creation date, and a list of all bookflows) for the book with that the given `book_id`.

**Parameters**: n/a  
**Return**: Information about the requested book.  
**Errors**: n/a  

    ~ > http --auth token: --json --verbose GET https://bookflow.bookalope.net/api/books/29fdc01dddb345268400bebef45b9d9e
    GET /api/books/29fdc01dddb345268400bebef45b9d9e HTTP/1.1
    Accept: application/json
    Accept-Encoding: gzip, deflate
    Authorization: Basic token
    Connection: keep-alive
    Content-Type: application/json
    Host: bookflow.bookalope.net
    User-Agent: HTTPie/0.9.2
    
    HTTP/1.1 200 OK
    Content-Length: 163
    Content-Type: application/json; charset=UTF-8
    Date: Fri, 18 Sep 2015 17:43:17 GMT
    Server: nginx/1.9.4
    
    {
        "book": {
            "bookflows": [
                {
                    "id": "ce1cebb526df44f5930cef992cd9d396",
                    "name": null
                }
            ],
            "created": "2015-09-18T17:34:17",
            "id": "29fdc01dddb345268400bebef45b9d9e",
            "name": "Great New Book"
        }
    }

`POST https://bookflow.bookalope.net/api/books/{book_id}`

Post to update the book name/title. 

**Parameters**: `name` (string) is the new name/title for the book.  
**Return**: n/a  
**Errors**: n/a  

    ~ > http --auth token: --json --verbose POST https://bookflow.bookalope.net/api/books/29fdc01dddb345268400bebef45b9d9e name="A Different Name"
    POST /api/books/29fdc01dddb345268400bebef45b9d9e HTTP/1.1
    Accept: application/json
    Accept-Encoding: gzip, deflate
    Authorization: Basic token
    Connection: keep-alive
    Content-Length: 28
    Content-Type: application/json
    Host: bookflow.bookalope.net
    User-Agent: HTTPie/0.9.2
    
    {
        "name": "A Different Name"
    }
    
    HTTP/1.1 200 OK
    Content-Length: 0
    Content-Type: text/html; charset=UTF-8
    Date: Fri, 18 Sep 2015 17:46:27 GMT
    Server: nginx/1.9.4

`DELETE https://bookflow.bookalope.net/api/books/{book_id}`

Delete the specified book. Note that deleting a book also deletes all of the book's bookflows.

**Parameters**: n/a  
**Return**: n/a  
**Errors**: n/a

    ~ > http --auth token: --verbose DELETE https://bookflow.bookalope.net/api/books/29fdc01dddb345268400bebef45b9d9e
    DELETE /api/books/29fdc01dddb345268400bebef45b9d9e HTTP/1.1
    Accept: application/json
    Accept-Encoding: gzip, deflate
    Authorization: Basic token
    Connection: keep-alive
    Content-Length: 0
    Content-Type: application/json
    Host: bookflow.bookalope.net
    User-Agent: HTTPie/0.9.2
    
    HTTP/1.1 204 No Content
    Content-Length: 0
    Content-Type: text/html; charset=UTF-8
    Date: Fri, 18 Sep 2015 17:49:28 GMT
    Server: nginx/1.9.4

### Bookflows

`GET https://bookflow.bookalope.net/api/books/{book_id}/bookflows`

Get the list of bookflow ids for the currect book.

**Parameters**: n/a  
**Return**: A list of bookflows and their meta information.  
**Errors**: n/a  

    ~ > http --auth token: --verbose GET https://bookflow.bookalope.net/api/books/29fdc01dddb345268400bebef45b9d9e/bookflows
    GET /api/books/29fdc01dddb345268400bebef45b9d9e/bookflows HTTP/1.1
    Accept: application/json
    Accept-Encoding: gzip, deflate
    Authorization: Basic token
    Connection: keep-alive
    Content-Type: application/json
    Host: bookflow.bookalope.net
    User-Agent: HTTPie/0.9.2
    
    HTTP/1.1 200 OK
    Content-Length: 73
    Content-Type: application/json; charset=UTF-8
    Date: Fri, 18 Sep 2015 17:55:48 GMT
    Server: nginx/1.9.4
    
    {
        "bookflows": [
            {
                "id": "c40973105a964afdad2e96f6b22b2c27",
                "name": null
            }
        ]
    }

`POST https://bookflow.bookalope.net/api/books/{book_id}/bookflows`

Post to create a new bookflow for the given book and return the new bookflow `id`.

**Parameter**: The meta data parameters are a number of string parameters that can be passed to the resource when creating or modifying a bookflow: `name`, `title`, `author` (optional, default `""`), `language` (optional, default `en-US`), `copyright` (optional, default `""`), `pubdate` (optional, default is creation date), `isbn` (optional, default `""`), `publisher` (optional, default `""`).  
**Return**: Information about the new bookflow.  
**Error**: n/a

    ~ > http --auth token: --json --verbose POST https://bookflow.bookalope.net/api/books/29fdc01dddb345268400bebef45b9d9e/bookflows name="Bookflow 1" title="Funky Title" author="Joe Regular"
    POST /api/books/29fdc01dddb345268400bebef45b9d9e/bookflows HTTP/1.1
    Accept: application/json
    Accept-Encoding: gzip, deflate
    Authorization: Basic token
    Connection: keep-alive
    Content-Length: 71
    Content-Type: application/json
    Host: bookflow.bookalope.net
    User-Agent: HTTPie/0.9.2
    
    {
        "author": "Joe Regular",
        "name": "Bookflow 1",
        "title": "Funky Title"
    }
    
    HTTP/1.1 201 Created
    Content-Length: 78
    Content-Type: application/json; charset=UTF-8
    Date: Fri, 18 Sep 2015 18:13:22 GMT
    Server: nginx/1.9.4
    
    {
        "bookflow": {
            "id": "56b7f0c370ec4a78b1154f09c5934f13",
            "name": "Bookflow 1"
        }
    }

`GET https://bookflow.bookalope.net/api/bookflows/{id}`

Get all metadata for the bookflow with that id. 

**Parameters**: n/a  
**Return**: All meta data for the bookflow.  
**Errors**: n/a

    ~ > http --auth token: --verbose GET https://bookflow.bookalope.net/api/bookflows/56b7f0c370ec4a78b1154f09c5934f13
    GET /api/bookflows/56b7f0c370ec4a78b1154f09c5934f13 HTTP/1.1
    Accept: application/json
    Accept-Encoding: gzip, deflate
    Authorization: Basic token
    Connection: keep-alive
    Content-Type: application/json
    Host: bookflow.bookalope.net
    User-Agent: HTTPie/0.9.2
    
    HTTP/1.1 200 OK
    Content-Length: 253
    Content-Type: application/json; charset=UTF-8
    Date: Fri, 18 Sep 2015 18:20:36 GMT
    Server: nginx/1.9.4
    
    {
        "bookflow": {
            "author": "Joe Regular",
            "copyright": "",
            "id": "56b7f0c370ec4a78b1154f09c5934f13",
            "isbn": "000-0-00-000000-0",
            "language": "en-US",
            "name": "Bookflow 1",
            "pubdate": "2015-09-18",
            "publisher": "",
            "step": "files",
            "title": "Funky Title"
        }
    }

`POST https://bookflow.bookalope.net/api/bookflows/{id}`

Post to update the meta data for the given bookflow.

**Parameters**: See meta data parameters above.  
**Return**: n/a  
**Errors**: n/a  

    http --auth token: --json --verbose POST https://bookflow.bookalope.net/api/bookflows/56b7f0c370ec4a78b1154f09c5934f13 name="Bookflow 1" title="Even funkier title" publisher="Publisher" author="Author"
    POST /api/bookflows/56b7f0c370ec4a78b1154f09c5934f13 HTTP/1.1
    Accept: application/json
    Accept-Encoding: gzip, deflate
    Authorization: Basic token
    Connection: keep-alive
    Content-Length: 99
    Content-Type: application/json
    Host: bookflow.bookalope.net
    User-Agent: HTTPie/0.9.2
    
    {
        "author": "Albert Author",
        "name": "Bookflow 1",
        "publisher": "Publisher",
        "title": "A Title of Nifty"
    }
    
    HTTP/1.1 200 OK
    Content-Length: 0
    Content-Type: text/html; charset=UTF-8
    Date: Fri, 18 Sep 2015 18:37:05 GMT
    Server: nginx/1.9.4

`DELETE https://bookflow.bookalope.net/api/bookflows/{id}`

Delete the specified bookflow.

**Parameters**: n/a  
**Return**: n/a  
**Errors**: n/a

    ~ > http --auth token: --verbose DELETE https://bookflow.bookalope.net/api/bookflows/56b7f0c370ec4a78b1154f09c5934f13
    DELETE /api/bookflows/56b7f0c370ec4a78b1154f09c5934f13 HTTP/1.1
    Accept: application/json
    Accept-Encoding: gzip, deflate
    Authorization: Basic token
    Connection: keep-alive
    Content-Length: 0
    Content-Type: application/json
    Host: bookflow.bookalope.net
    User-Agent: HTTPie/0.9.2
    
    HTTP/1.1 204 No Content
    Content-Length: 0
    Content-Type: text/html; charset=UTF-8
    Date: Fri, 18 Sep 2015 22:26:41 GMT
    Server: nginx/1.9.4

### Document and Image Handling

The original text document and images for a bookflow are handled similar to the `files` view of the website. Because request parameters are passed as a JSON string in the request body, the file to upload must be [base64](https://en.wikipedia.org/wiki/Base64) encoded and the resulting string is used as the `file` parameter.

`GET https://bookflow.bookalope.net/api/bookflows/{id}/files/document`

Get the bookflow's original document file, if it exists.

**Parameter**: n/a  
**Return**: The original text document for the bookflow.  
**Error**: `404` if the bookflow did not contain an original text document.

    ~ > http --auth token: --verbose --download GET https://bookflow.bookalope.net/api/bookflows/36582d54166540638efc286e655fb657/files/document
    GET /api/bookflows/36582d54166540638efc286e655fb657/files/document HTTP/1.1
    Accept: application/json
    Authorization: Basic token
    Connection: keep-alive
    Content-Type: application/json
    Host: bookflow.bookalope.net
    User-Agent: HTTPie/0.9.2
    
    HTTP/1.1 200 OK
    Content-Disposition: attachment; filename="bla.odt"
    Content-Length: 19337
    Content-Type: application/vnd.oasis.opendocument.text; charset=UTF-8
    Date: Fri, 18 Sep 2015 22:49:43 GMT
    Server: nginx/1.9.4
    
    Downloading 18.88 kB to "bla.odt"
    Done. 18.88 kB in 0.00050s (36.66 MB/s)

`POST https://bookflow.bookalope.net/api/bookflows/{id}/files/document`

Post the original document file for the given bookflow; if the bookflow has already a document file, then this call fails. This causes the Bookalope server to analyze the document and to extract content from it based on built-in heuristics. The interactive *Import* and *Content* steps from the website are incorporated here, and the bookflow moves forward to the *Convert* step automatically as if the user clicked *Next* on the website.

**Parameters**: `file` (string) is a base64 encoded text document. `filename` (string) is the original file name of the text document.`filetype` (string) must be one of `doc` or `gutenberg`, describing how the document file is to be interpreted by Bookalope.  
**Return**: n/a  
**Error**: `406` if the bookflow already contains a document or if the file type is unsupported, `413` if the posted document is too large (more than 12MB).

    ~ > base64 bla.odt > bla.odt.b64
    ~ > http --auth token: --json --verbose POST https://bookflow.bookalope.net/api/bookflows/36582d54166540638efc286e655fb657/files/document file=@bla.odt.b64 filename=bla.odt filetype=doc
    POST /api/bookflows/36582d54166540638efc286e655fb657/files/document HTTP/1.1
    Accept: application/json
    Accept-Encoding: gzip, deflate
    Authorization: Basic token
    Connection: keep-alive
    Content-Length: 26518
    Content-Type: application/json
    Host: bookflow.bookalope.net
    User-Agent: HTTPie/0.9.2
    
    {
        "file": "UEsDBBQAAAgAAASXwUZexjIMJwAAACcAAAAIAAAAbWltZXR5cGVhcHBsaWNhdGlvbi92bmQub2Fz\na..."
        "filename": "bla.odt",
        "filetype": "doc"
    }
    
    HTTP/1.1 200 OK
    Content-Length: 0
    Content-Type: text/html; charset=UTF-8
    Date: Fri, 18 Sep 2015 22:47:25 GMT
    Server: nginx/1.9.4

`GET https://bookflow.bookalope.net/api/bookflows/{id}/files/image`

Get the bookflow's cover image. If no cover image was provided yet, then one will be generated on the fly. This generated cover image is not stored for the bookflow.

**Parameters**: `name` (string) is the name or identifier of the image; this parameter is optional and defaults to `'cover-image'`.  
**Return**: The requested image.  
**Errors**: `406` if the document is not in the `convert` step, or if the requested image name could not be found in the book.

    ~ > http --auth token: --verbose --download GET https://bookflow.bookalope.net/api/bookflows/36582d54166540638efc286e655fb657/files/image
    GET /api/bookflows/36582d54166540638efc286e655fb657/files/image HTTP/1.1
    Accept: application/json
    Authorization: Basic token
    Connection: keep-alive
    Content-Type: application/json
    Host: bookflow.bookalope.net
    User-Agent: HTTPie/0.9.2
    
    HTTP/1.1 200 OK
    Content-Disposition: attachment; filename="36582d54166540638efc286e655fb657-cover-image.png"
    Content-Length: 16784
    Content-Type: image/png; charset=UTF-8
    Date: Mon, 21 Sep 2015 16:37:36 GMT
    Server: nginx/1.9.4
    
    Downloading 16.39 kB to "36582d54166540638efc286e655fb657-cover-image.png"
    Done. 16.39 kB in 0.00058s (27.79 MB/s)

`POST https://bookflow.bookalope.net/api/bookflows/{id}/files/image`

Post an image with the given name or id for the bookflow. The only image currently supported is the cover image.

**Parameters**: `name` (string) is the name or identifier for the image; this parameter is optional and defaults to `'cover-image'`, the book's cover image. `caption` (string) is the caption for the image; this parameter is optional and if none is given then an existing caption for the image is removed. `file` (string) is the base64 encoded image. `filename` (string) is the original file name of the image.  
**Return**: n/a  
**Errors**: `400` if the image is not one of the supported formats (jpg, png, gif); `406` if the bookflow does not contain a document, or the document is not in `convert` step, or no image with the specified name existed; `413` if the posted document is too large (more than 12MB).  

    ~ > base64 cover.png > cover.png.b64
    ~ > http --auth token: --json --verbose POST https://bookflow.bookalope.net/api/bookflows/36582d54166540638efc286e655fb657/files/image file=@cover.png.b64 filename=cover.png name="cover-image"
    POST /api/bookflows/36582d54166540638efc286e655fb657/files/image HTTP/1.1
    Accept: application/json
    Accept-Encoding: gzip, deflate
    Authorization: Basic token
    Connection: keep-alive
    Content-Length: 20109
    Content-Type: application/json
    Host: bookflow.bookalope.net
    User-Agent: HTTPie/0.9.2
    
    {
        "file": "iVBORw0KGgoAAAANSUhEUgAAAyAAAASwCAIAAACM07nyAAAABmJLR0QA/wD/AP+gvaeTAAAgAElE\n...",
        "filename": "cover.png",
        "name": "cover-image"
    }
    
    HTTP/1.1 200 OK
    Content-Length: 0
    Content-Type: text/html; charset=UTF-8
    Date: Mon, 21 Sep 2015 16:44:10 GMT
    Server: nginx/1.9.4

### Scratchpad

Every bookflow has its private scratchpad; a scratchpad is a dictionary of key-value pairs, where both keys and values are strings of 128 characters maximum length. With every `step` transition of a bookflow, the scratchpad is being erased.

`GET https://bookflow.bookalope.net/api/bookflows/{id}/scratchpad`

Get the current content of a bookflow's scratchpad.

**Parameters**: n/a  
**Return**: the scratchpad dictionary  
**Errors**: n/a  

    ~ > http --json --auth token: --verbose GET http://localhost:6543/api/bookflows/36582d54166540638efc286e655fb657/scratchpad
    GET /api/bookflows/36582d54166540638efc286e655fb657/scratchpad HTTP/1.1
    Accept: application/json
    Accept-Encoding: gzip, deflate
    Authorization: Basic token
    Connection: keep-alive
    Content-Type: application/json
    Host: bookflow.bookalope.net
    User-Agent: HTTPie/0.9.2

    HTTP/1.1 200 OK
    Content-Length: 18
    Content-Type: application/json; charset=UTF-8
    Date: Thu, 23 Jun 2016 21:39:41 GMT
    Server: waitress

    {
        "scratchpad": {}
    }

`POST https://bookflow.bookalope.net/api/bookflows/{id}/scratchpad`

Post, i.e. add or update entries of a bookflow's scratchpad. If they `key` does not yet exist, add the key-value pair; if the `key` already exists, update the value only.

**Parameters**: A dictionary of key-value pairs, both keys and values must be strings no longer than 128 characters long.  
**Return**: n/a  
**Errors**: n/a  

    ~ > http --json --auth token: --verbose POST http://localhost:6543/api/bookflows/36582d54166540638efc286e655fb657/scratchpad scratchpad:='{"foo":"bla"}'
    POST /api/bookflows/36582d54166540638efc286e655fb657/scratchpad HTTP/1.1
    Accept: application/json
    Accept-Encoding: gzip, deflate
    Authorization: Basic token
    Connection: keep-alive
    Content-Length: 30
    Content-Type: application/json
    Host: bookflow.bookalope.net
    User-Agent: HTTPie/0.9.2

    {
        "scratchpad": {
            "foo": "bla"
        }
    }

    HTTP/1.1 200 OK
    Content-Length: 0
    Content-Type: text/html; charset=UTF-8
    Date: Thu, 23 Jun 2016 21:39:45 GMT
    Server: waitress

`DELETE https://bookflow.bookalope.net/api/bookflows/{id}/scratchpad`

Delete and clear the content of a bookflow's scratchpad. Note that Bookalope executes this function with every `step` transition of a bookflow.

**Parameters**: n/a  
**Return**: n/a  
**Errors**: n/a  

    ~ > http --json --auth token: --verbose DELETE http://localhost:6543/api/bookflows/36582d54166540638efc286e655fb657/scratchpad
    DELETE /api/bookflows/36582d54166540638efc286e655fb657/scratchpad HTTP/1.1
    Accept: application/json
    Accept-Encoding: gzip, deflate
    Authorization: Basic token
    Connection: keep-alive
    Content-Length: 0
    Content-Type: application/json
    Host: bookflow.bookalope.net
    User-Agent: HTTPie/0.9.2

    HTTP/1.1 204 No Content
    Content-Length: 0
    Content-Type: text/html; charset=UTF-8
    Date: Thu, 23 Jun 2016 21:40:03 GMT
    Server: waitress

### Conversion and Download

`GET https://bookflow.bookalope.net/api/formats`

Get two lists of supported import and export file formats that Bookalope supports. Both import and export lists contain two-element dictionaries, where the `mime` key holds the mime type of the file format and the `exts` key holds a list of file name extensions for the file format.

**Parameters**: n/a

    ~ > http --auth token: --verbose GET https://bookflow.bookalope.net/api/formats
    GET /api/formats HTTP/1.1
    Accept: application/json
    Accept-Encoding: gzip, deflate
    Authorization: Basic token
    Connection: keep-alive
    Host: bookflow.bookalope.net
    User-Agent: HTTPie/0.9.2

    HTTP/1.1 200 OK
    Content-Length: 1932
    Content-Type: application/json; charset=UTF-8
    Date: Sun, 14 Feb 2016 22:53:31 GMT
    Server: nginx/1.9.7
    
    {
        "formats": {
            "export": [
                {
                    "exts": [
                        "epub",
                        "epub3"
                    ],
                    "mime": "application/epub+zip"
                },
                {
                    "exts": [
                        "icml"
                    ],
                    "mime": "application/xml"
                },
                ...
            ],
            "import": [
                {
                    "exts": [
                        "dot",
                        "dotx",
                        "docx",
                        "dotm",
                        "doc",
                        "docm"
                    ],
                    "mime": "application/msword"
                },
                {
                    "exts": [
                        "tsv",
                        "csv",
                        "tab",
                        "txt"
                    ],
                    "mime": "text/plain"
                },
                ...
            ]
        }
    }

`GET https://bookflow.bookalope.net/api/styles`

Get information about the available visual styles for one or for all target book formats.

**Parameters**: The `format` (string) parameter is optional and specifies the target book file format for which style information is retrieved; if none is given style information is retrieved for *all* supported formats.

    ~ > http --auth token: --verbose GET https://bookflow.bookalope.net/api/styles format==epub
    GET /api/styles?format=epub HTTP/1.1
    Accept: application/json
    Accept-Encoding: gzip, deflate
    Authorization: Basic token
    Connection: keep-alive
    Content-Length: 18
    Content-Type: application/json
    Host: bookflow.bookalope.net
    User-Agent: HTTPie/0.9.2

    HTTP/1.1 200 OK
    Content-Length: 158
    Content-Type: application/json; charset=UTF-8
    Date: Wed, 14 Oct 2015 18:18:07 GMT
    Server: waitress
    
    {
        "name": "epub",
        "styles": [
            {
                "info": {
                    "description": "Simple and functional Bookalope styling.",
                    "name": "Default",
                    "price-api": "9.95"
                },
                "name": "default"
            }
        ]
    }

`GET https://bookflow.bookalope.net/api/bookflows/{id}/convert`

Convert and download the document into a target format and styling.

**Parameters**: The `format` (string) parameter determines which target format the book is to be converted into. The `format` is any of the export file name extensions returned by the `api/formats` call (i.e. `epub`, `epub3`, `mobi`, `pdf`, `icml`, or `docx`). The `styling` (string) parameter is optional and selects the style for the generated book; defaults to `default` which also is the only supported value at the moment. The `version` (string) parameter is optional and determines whether Bookalope generates a `test` or `final` version of the book; defaults to `test`.  
**Return**: The converted document.  
**Errors**: `406` if the bookflow step is anything other than `convert`. `409` if `version=final` and the user has no billing information or if the server explicitly disallows only `final`. `500` if a credit card charge failed.

    ~ > http --auth token: --verbose --download GET https://bookflow.bookalope.net/api/bookflows/36582d54166540638efc286e655fb657/convert format==epub
    GET /api/bookflows/36582d54166540638efc286e655fb657/convert?format=epub HTTP/1.1
    Accept: application/json
    Authorization: Basic token
    Connection: keep-alive
    Content-Length: 18
    Content-Type: application/json
    Host: bookflow.bookalope.net
    User-Agent: HTTPie/0.9.2
    
    HTTP/1.1 200 OK
    Content-Disposition: attachment; filename="36582d54166540638efc286e655fb657.epub"
    Content-Length: 22286
    Content-Type: application/epub+zip; charset=UTF-8
    Date: Fri, 18 Sep 2015 22:56:24 GMT
    Server: nginx/1.9.4
    
    Downloading 21.76 kB to "36582d54166540638efc286e655fb657.epub"
    Done. 21.76 kB in 0.00037s (57.44 MB/s)
