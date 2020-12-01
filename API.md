<img src="https://bookalope.net/img/bookalope-logo-black.png" width="50%" alt="Bookalope Logo">

# The Bookalope REST API

## Table of Content

- [Overview](#overview)
- [User Profile](#user-profile)
  - [GET /api/profile](#get-profile)  
  Return a user’s profile information
  - [POST /api/profile](#post-profile)  
  Modify a user’s profile information
- [Books](#books)
  - [GET /api/books](#get-books)  
  Return a list of current books
  - [POST /api/books](#post-books)  
  Create a new book
  - [GET /api/books/{book_id}](#get-books-id)  
  Return information about the book with id `book_id`
  - [POST /api/books/{book_id}](#post-books-id)  
  Modify information for the book with id `book_id`
  - [DELETE /api/books/{book_id}](#delete-books-id)  
  Delete the book with id `book_id` and all of its bookflows
- [Bookshelves](#bookshelves)
  - [GET /api/bookshelves](#get-bookshelves)  
  Return a list of bookshelves
  - [POST /api/bookshelves](#post-bookshelves)  
  Create a new bookshelf
  - [GET /api/bookshelves/{bookshelf_id}](#get-bookshelves-id)  
  Return information about the bookshelf with id `bookshelf_id`
  - [POST /api/bookshelves/{bookshelf_id}](#post-bookshelves-id)  
  Modify information for the bookshelf with id `bookshelf_id`
  - [DELETE /api/bookshelves/{bookshelf_id}](#delete-bookshelves-id)  
  Delete the bookshelf with id `bookshelf_id`, and all of its books
- [Bookflows](#bookflows)
  - [GET /api/books/{book_id}/bookflows](#get-bookflows)  
  Return a list of bookflows for the book with id `book_id`
  - [POST /api/books/{book_id}/bookflows](#post-bookflows)  
  Create a new bookflow for the given book with id `book_id`
  - [GET /api/bookflows/{id}](#get-bookflows-id)  
  Return information about the bookflow with id `id`
  - [POST /api/bookflows/{id}](#post-bookflows-id)  
  Modify the information of the bookflow with id `id`
  - [DELETE /api/bookflows/{id}](#delete-bookflows-id)  
  Delete the bookflow with id `id`
  - [POST /api/bookflows/{id}/credit](#post-bookflows-id-credit)  
  Add a previously purchased conversion credit to the bookflow with id `id`.
- [Document and Image Handling](#document-and-image-handling)
  - [GET /api/bookflows/{id}/files/document](#get-bookflows-files-document)  
  Return the bookflow’s original document file, if it exists
  - [POST /api/bookflows/{id}/files/document](#post-bookflows-files-document)  
  Upload a document for analysis for the given bookflow with id `id`
  - [GET /api/bookflows/{id}/files/image](#get-bookflows-files-image)  
  Return an image for the bookflow with id `id`
  - [POST /api/bookflows/{id}/files/image](#post-bookflows-files-image)  
  Upload an image for the book of the bookflow with id `id`
- [Scratchpad](#scratchpad)
  - [GET /api/bookflows/{id}/scratchpad](#get-scratchpad)  
  Return the content of the bookflow’s scratchpad
  - [POST /api/bookflows/{id}/scratchpad](#post-scratchpad)  
  Add, update, or delete entries of the bookflow’s scratchpad
  - [DELETE /api/bookflows/{id}/scratchpad](#delete-scratchpad)  
  Clear the bookflow’s scratchpad
- [Conversion and Download](#conversion-and-download)
  - [GET /api/formats](#get-formats)  
  Return a list of all supported import and export file formats
  - [GET /api/styles](#get-styles)  
  Return styling information for all or a specific export file format
  - [POST /api/bookflows/{id}/convert](#post-bookflows-convert)  
  Initiate the conversion of the bookflow’s document
  - [POST /api/bookflows/{id}/restart](#post-bookflows-restart)  
  Restart the bookflow from scratch
  - [GET /api/bookflows/{id}/download/{format}/status](#get-bookflows-download-status)  
  Check the status of the conversion of the bookflow’s document
  - [GET /api/bookflows/{id}/download/{format}](#get-bookflows-download)  
  Download the bookflow’s converted document
  - [DELETE /api/bookflows/{id}/download/{format}](#delete-bookflows-download)  
  Delete the bookflow’s converted document

## Overview

[Bookalope](https://bookalope.net/) provides web services to the user through a [REST API](https://en.wikipedia.org/wiki/Representational_state_transfer). All resource URLs are based on `https://bookflow.bookalope.net/api` and require [basic authenticated client access](https://en.wikipedia.org/wiki/Basic_access_authentication) with each request.

When a user logs into Bookalope through the website, a session and an API token are generated. This API token can be found on the user’s profile page, and is used to authenticate the REST requests. The token is valid for as long as the user’s account exists, and can be changed any time.

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

### API Version

At this point Bookalope does _not_ provide backwards compatible versioning, meaning that the server may break existing clients when breaking changes go live. Therefore, clients are required to check the `X-Bookalope-Api-Version` response header, and implement changes to that header value accordingly.

    ~ > date
    Sun Mar 15 10:16:23 AEST 2020
    ~ > http --headers --auth token: head https://bookflow.bookalope.net/api/profile | grep X-Bookalope
    X-Bookalope-Api-Version: 1.2.0
    X-Bookalope-Version: 1.4.6

## User Profile

A user profile contains relevant information about the current (i.e. requesting) user.

<a name="get-profile"></a>`GET https://bookflow.bookalope.net/api/profile`

Get the current profile data.

**Parameters**: n/a  
**Return**: The first and last name.  
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

<a name="post-profile"></a>`POST https://bookflow.bookalope.net/api/profile`

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

## Books

<a name="get-books"></a>`GET https://bookflow.bookalope.net/api/books`

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
                        "name": "Bookflow 1",
                        "step": "structure"
                    },
                    {
                        "id": "a469de3069dd4b9ca58b425352107310",
                        "name": "Bookflow 2"
                        "step": "convert"
                    }
                ],
                "bookshelf": null,
                "created": "2015-09-16T00:06:41",
                "id": "f99f21dd598840d5b7caf9bf39a51b00",
                "name": "Bla Test"
            }
        ]
    }

<a name="post-books"></a> `POST https://bookflow.bookalope.net/api/books`

Create a new book with a single empty bookflow.

**Parameters**: `name` (string) is the title for the new book, and `bookshelf_id` (string) is the id of an existing bookshelf.  
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
                    "name": null,
                    "step": "files"
                }
            ],
            "bookshelf": null,
            "created": "2015-09-18T17:34:16.661944",
            "id": "29fdc01dddb345268400bebef45b9d9e",
            "name": "Great New Book"
        }
    }

<a name="get-books-id"></a> `GET https://bookflow.bookalope.net/api/books/{book_id}`

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
                    "name": null,
                    "step": "content"
                }
            ],
            "bookshelf": null,
            "created": "2015-09-18T17:34:17",
            "id": "29fdc01dddb345268400bebef45b9d9e",
            "name": "Great New Book"
        }
    }

<a name="post-books-id"></a> `POST https://bookflow.bookalope.net/api/books/{book_id}`

Post to update the book name/title. 

**Parameters**: `name` (string) is the new name/title for the book, and `bookshelf_id` (string) is the id of an existing bookshelf.  
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

<a name="delete-books-id"></a> `DELETE https://bookflow.bookalope.net/api/books/{book_id}`

Delete the specified book. Note that deleting a book also deletes all of the book’s bookflows.

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

## Bookshelves

**Note:** In addition to the endpoints below, use [`POST /api/books/{book_id}`](#post-books-id) to move the specified book onto an existing bookshelf or [`POST /api/books`](#post-books) to create a new book on an existing bookshelf.

<a name="get-bookshelves"></a>`GET https://bookflow.bookalope.net/api/bookshelves`

Get the list of bookshelves.

**Parameters**: n/a  
**Return**: A list of bookshelves and some information about each.  
**Errors**: n/a  

    ~ > http --auth token: --verbose GET https://bookflow.bookalope.net/api/bookshelves
    GET /api/bookshelves HTTP/1.1
    Accept: application/json
    Accept-Encoding: gzip, deflate
    Authorization: Basic token
    Connection: keep-alive
    Content-Type: application/json
    Host: bookflow.bookalope.net
    User-Agent: HTTPie/1.0.2

    HTTP/1.1 200 OK
    Content-Length: 4689
    Content-Type: application/json
    Date: Thu, 30 May 2019 07:23:20 GMT
    Server: nginx/1.15.7

    {
        "bookshelves": [
            {
                "books": [
                    {
                        "bookflows": 1,
                        "id": "25d4fd28c6264132b00b1a129407a134",
                        "name": "Schnufte Book"
                    },
                    …
                ],
                "created": "2019-05-17T05:07:49",
                "description": null,
                "id": "52945eebbb3d4ca8b4a77bf20e67a5a8",
                "name": "My Bookshelf"
            },
            …
        ]
    }

<a name="post-bookshelves"></a>`POST https://bookflow.bookalope.net/api/bookshelves`

Create a new bookshelf.

**Parameters**: The only parameter is the `name` (required) of the new bookshelf, and an optional `description`.  
**Return**: Information about the new bookshelf.  
**Errors**: n/a  

    ~ > http --auth token: --verbose POST https://beta.bookalope.net/api/bookshelves name="My Bookshelf" description="This is my awesome bookshelf"
    POST /api/bookshelves HTTP/1.1
    Accept: application/json
    Accept-Encoding: gzip, deflate
    Authorization: Basic token
    Connection: keep-alive
    Content-Type: application/json
    Host: bookflow.bookalope.net
    User-Agent: HTTPie/1.0.2

    {
        "description": "This is my awesome bookshelf",
        "name": "My Bookshelf",
    }

    HTTP/1.1 201 Created
    Content-Length: 128
    Content-Type: application/json
    Date: Thu, 30 May 2019 07:56:39 GMT
    Server: nginx/1.15.7

    {
        "bookshelf": {
            "books": [],
            "created": "2019-05-30T07:56:39",
            "description": "This is my awesome bookshelf",
            "id": "1600423e867840259527e5a4a7958f4b",
            "name": "My Bookshelf"
        }
    }

<a name="get-bookshelves-id"></a>`GET https://bookflow.bookalope.net/api/bookshelves/{bookshelf_id}`

Get information about the bookshelf with id `bookshelf_id`.

**Parameters**: n/a  
**Return**: Information about the specified bookshelf.  
**Errors**: n/a  

    ~ > http --auth token: --verbose GET https://beta.bookalope.net/api/bookshelves/1600423e867840259527e5a4a7958f4b
    GET /api/bookshelves/1600423e867840259527e5a4a7958f4b HTTP/1.1
    Accept: application/json
    Accept-Encoding: gzip, deflate
    Authorization: Basic token
    Connection: keep-alive
    Content-Type: application/json
    Host: bookflow.bookalope.net
    User-Agent: HTTPie/1.0.2

    HTTP/1.1 200 OK
    Content-Length: 128
    Content-Type: application/json
    Date: Thu, 30 May 2019 08:07:07 GMT
    Server: nginx/1.15.7

    {
        "bookshelf": {
            "books": [],
            "created": "2019-05-30T07:56:39",
            "description": "This is my awesome bookshelf",
            "id": "1600423e867840259527e5a4a7958f4b",
            "name": "My Bookshelf"
        }
    }

<a name="post-bookshelves-id"></a>`POST https://bookflow.bookalope.net/api/bookshelves/{bookshelf_id}`

Update the information for the specified bookshelf.

**Parameters**: The only parameter is the `name` (required) of the new bookshelf.  
**Return**: n/a  
**Errors**: n/a  

    ~ > http --auth token: --verbose POST https://beta.bookalope.net/api/bookshelves/1600423e867840259527e5a4a7958f4b name="Great Shelf of Books"
    POST /api/bookshelves/1600423e867840259527e5a4a7958f4b HTTP/1.1
    Accept: application/json
    Accept-Encoding: gzip, deflate
    Authorization: Basic token
    Connection: keep-alive
    Content-Type: application/json
    Host: bookflow.bookalope.net
    User-Agent: HTTPie/1.0.2

    {
        "name": "Great Shelf of Books"
    }

    HTTP/1.1 200 OK
    Content-Length: 0
    Content-Type: application/json
    Date: Thu, 30 May 2019 08:12:11 GMT
    Server: nginx/1.15.7

<a name="delete-bookshelves-id"></a>`DELETE https://bookflow.bookalope.net/api/bookshelves/{bookshelf_id}`

Delete the specified bookshelf, and with it all of its associated books and their bookflows.

**Parameters**: n/a  
**Return**: n/a  
**Errors**: n/a  

    ~ > http --auth token: --verbose DELETE https://beta.bookalope.net/api/bookshelves/1600423e867840259527e5a4a7958f4b
    DELETE /api/bookshelves/1600423e867840259527e5a4a7958f4b HTTP/1.1
    Accept: application/json
    Accept-Encoding: gzip, deflate
    Authorization: Basic token
    Connection: keep-alive
    Content-Type: application/json
    Host: bookflow.bookalope.net
    User-Agent: HTTPie/1.0.2

    HTTP/1.1 204 No Content
    Content-Length: 4
    Content-Type: application/json
    Date: Thu, 30 May 2019 08:15:44 GMT
    Server: nginx/1.15.7

## Bookflows

<a name="get-bookflows"></a>`GET https://bookflow.bookalope.net/api/books/{book_id}/bookflows`

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
                "credit": null,
                "id": "c40973105a964afdad2e96f6b22b2c27",
                "name": null,
                "step": "convert"
            }
        ]
    }

<a name="post-bookflows"></a>`POST https://bookflow.bookalope.net/api/books/{book_id}/bookflows`

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
            "credit": null,
            "id": "56b7f0c370ec4a78b1154f09c5934f13",
            "name": "Bookflow 1",
            "step": "files"
        }
    }

<a name="get-bookflows-id"></a>`GET https://bookflow.bookalope.net/api/bookflows/{id}`

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
            "credit": {
                "formats": [
                    "epub3",
                    "mobi",
                    "pdf"
                ],
                "type": "basic"
            },
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

<a name="post-bookflows-id"></a>`POST https://bookflow.bookalope.net/api/bookflows/{id}`

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

<a name="delete-bookflows-id"></a> `DELETE https://bookflow.bookalope.net/api/bookflows/{id}`

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

<a name="post-bookflows-id-credit"></a> `POST https://bookflow.bookalope.net/api/bookflows/{id}/credit`

Using the [Billing page](https://bookflow.bookalope.net/billing) a user can purchase a [Plan](https://bookalope.net/#pricing) which credits a number of conversions to the user’s account. This endpoint then allows a user to spend one of these credits on the specified Bookflow.

**Parameters**: The type of plan from which the Bookflow credit should be subtracted, either `"basic"` or `"pro"`.  
**Return**: n/a  
**Errors**: `400` if the Bookflow has already been credited, if the Bookflow is currently processing or has failed, or if no credits are available for the specified plan.

    ~ > http --auth token: --verbose POST https://bookflow.bookalope.net/api/bookflows/80c0ef19b8d142708a26596d49de0f1c/credit type=basic
    POST /api/bookflows/80c0ef19b8d142708a26596d49de0f1c/credit HTTP/1.1
    Accept: application/json, */*
    Accept-Encoding: gzip, deflate
    Authorization: Basic token
    Connection: keep-alive
    Content-Length: 17
    Content-Type: application/json
    Host: bookflow.bookalope.net
    User-Agent: HTTPie/1.0.3

    {
        "type": "basic"
    }

    HTTP/1.1 200 OK
    Content-Length: 4
    Content-Type: application/json
    Date: Tue, 24 Sep 2019 08:56:58 GMT
    Server: waitress
    X-Content-Type-Options: nosniff

## Document and Image Handling

The original text document and images for a bookflow are handled similar to the `files` view of the website. Because request parameters are passed as a JSON string in the request body, the file to upload must be [base64](https://en.wikipedia.org/wiki/Base64) encoded and the resulting string is used as the `file` parameter.

<a name="get-bookflows-files-document"></a>`GET https://bookflow.bookalope.net/api/bookflows/{id}/files/document`

Get the bookflow’s original document file, if it exists.

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

<a name="post-bookflows-files-document"></a>`POST https://bookflow.bookalope.net/api/bookflows/{id}/files/document`

Post the original document file for the given bookflow; if the bookflow has already a document file, then this call fails. This causes the Bookalope server to analyze the document and to extract content from it based on built-in heuristics. The interactive *Structure* and *Content* steps from the website are incorporated here, and the bookflow moves forward to the *Convert* step automatically as if the user clicked *Next* on the website.

**Parameters**: `file` (string) is a base64 encoded text document. `filename` (string) is the original file name of the text document. `filetype` (string) is optional but must be one of `"doc"`, `"epub"`, or `"gutenberg"`, describing how the document file is to be interpreted by Bookalope; if `filetype` is missing then Bookalope attempts to figure out the file type itself. `skip_analysis` (boolean) must be either `true` or `false` indicating whether Bookalope should ignore the results of structure and content analysis and produce a flat & semantically unstructured document (reusing the document’s original styling), or if the document should be structured properly (defaults to `false`) based on Bookalope’s semantic structure classification. `beeline` (boolean) must be either `true` or `false` indicating whether to run the bookflow all the way to its `"convert"` step (`true`), or whether to stop at the `"structure"` step (`false`) for review.  
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

<a name="get-bookflows-files-image"></a>`GET https://bookflow.bookalope.net/api/bookflows/{id}/files/image`

Get the bookflow’s cover image. If no cover image was provided yet, then one will be generated on the fly. This generated cover image is not stored for the bookflow.

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

<a name="post-bookflows-files-image"></a>`POST https://bookflow.bookalope.net/api/bookflows/{id}/files/image`

Post an image with the given name or id for the bookflow. The only image currently supported is the cover image.

**Parameters**: `name` (string) is the name or identifier for the image; this parameter is optional and defaults to `'cover-image'`, the book’s cover image. `caption` (string) is the caption for the image; this parameter is optional and if none is given then an existing caption for the image is removed. `file` (string) is the base64 encoded image. `filename` (string) is the original file name of the image.  
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

## Scratchpad

Every bookflow has its private scratchpad; a scratchpad is a dictionary of key-value pairs, where keys are strings of 128 characters maximum length and values are of type `Boolean`, `Number`, `String`s of 2048 characters maximum length, or lists thereof. With every `step` transition of a bookflow, the scratchpad is being erased.

<a name="get-scratchpad"></a>`GET https://bookflow.bookalope.net/api/bookflows/{id}/scratchpad`

Get the current content of a bookflow’s scratchpad.

**Parameters**: n/a  
**Return**: The scratchpad dictionary.  
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

<a name="post-scratchpad"></a>`POST https://bookflow.bookalope.net/api/bookflows/{id}/scratchpad`

Post, i.e. add, update, or delete entries of a bookflow’s scratchpad. If they `key` does not yet exist, add the key-value pair; if the `key` already exists, update the value only; if a value is `null` then the key-value pair is deleted from the scratchpad. If the value is a list and the bookflow’s scratchpad contains a list with the same `key` then the list is appended to the existing one; else the value overrides the existing value.

**Parameters**: A dictionary of key-value pairs, where keys are strings no longer than 128 characters and values must be either `null` or of type `boolean`, `number`, `string` no longer than 4096 characters. If a value is a list, then its elements must be either `null` or of type `boolean`, `number`, `string` no longer than 128 characters or a list of values of those simple types.  
**Return**: n/a  
**Errors**: `400` if the bookflow is currently processing or has failed to process.  

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
            "foo": "bla",
            "bar": [null, "string", [1, 2, 3]]
        }
    }

    HTTP/1.1 200 OK
    Content-Length: 0
    Content-Type: text/html; charset=UTF-8
    Date: Thu, 23 Jun 2016 21:39:45 GMT
    Server: waitress

<a name="delete-scratchpad"></a>`DELETE https://bookflow.bookalope.net/api/bookflows/{id}/scratchpad`

Delete and clear the content of a bookflow’s scratchpad. Note that Bookalope executes this function with every `step` transition of a bookflow.

**Parameters**: n/a  
**Return**: n/a  
**Errors**: `400` if the bookflow is currently processing or has failed to process.  

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

## Conversion and Download

<a name="get-formats"></a>`GET https://bookflow.bookalope.net/api/formats`

Get two lists of supported import and export file formats that Bookalope supports. Both import and export lists contain two-element dictionaries, where the `mime` key holds the mime type of the file format and the `exts` key holds a list of file name extensions for the file format.

**Parameters**: n/a  
**Return**: A dictionary for import and export formats and their descriptions; here, a description includes the file format’s filename extension and its MIME type.  
**Errors**: n/a  

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
                        "epub3"
                    ],
                    "mime": "application/epub+zip"
                },
                {
                    "exts": [
                        "idml"
                    ],
                    "mime": "application/vnd.adobe.indesign-idml-package"
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

<a name="get-styles"></a>`GET https://bookflow.bookalope.net/api/styles`

Get information about the available visual styles for one or for all target book formats.

**Parameters**: The `format` (string) parameter is optional and specifies the target book file format for which style information is retrieved; if none is given style information is retrieved for *all* supported formats.  
**Return**: A dictionary of formats mapping to a list of styles and their description.  
**Errors**: n/a  

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
    Server: nginx/1.9.7
    
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

<a name="post-bookflows-convert"></a>`POST https://bookflow.bookalope.net/api/bookflows/{id}/convert`

Initiate the conversion of the bookflow’s document into a target format and styling.

**Parameters**: The `format` (string) parameter determines which target format the book is to be converted into. The `format` is any of the export file name extensions returned by the `api/formats` call (i.e. `epub`, `epub3`, `mobi`, `pdf`, `icml`, `idml`, or `docx`). The `styling` (string) parameter is optional and selects the style for the generated book; defaults to `default` which also is the only supported value at the moment. The `version` (string) parameter is optional and determines whether Bookalope generates a `test` or `final` version of the book; defaults to `test`.  
**Return**: A handle, URL, and current processing status of the converted document.  
**Errors**: `406` if the bookflow step is anything other than `convert`. `409` if `version=final` and the user has no billing information or if the server explicitly disallows only `final`. `500` if a credit card charge failed.

    ~ > http --auth token: --verbose POST https://bookflow.bookalope.net/api/bookflows/d441bf24d81b4f7a849fc77359f6d775/convert format=epub
    POST /api/bookflows/d441bf24d81b4f7a849fc77359f6d775/convert HTTP/1.1
    Accept: application/json, */*
    Accept-Encoding: gzip, deflate
    Authorization: Basic token
    Connection: keep-alive
    Content-Length: 0
    Content-Type: application/json
    Host: bookflow.bookalope.net
    User-Agent: HTTPie/0.9.8

    {
        "format": "epub"
    }

    HTTP/1.1 200 OK
    Content-Length: 180
    Content-Type: application/json
    Date: Fri, 25 May 2018 05:20:41 GMT
    Server: nginx/1.9.7
    X-Content-Type-Options: nosniff

    {
        "download_url": "https://bookflow.bookalope.net/api/bookflows/d441bf24d81b4f7a849fc77359f6d775/download/211fc053a02d487cbb412c25fc7f8501",
        "status": "processing"
    }

<a name="post-bookflows-restart"></a>`POST https://bookflow.bookalope.net/api/bookflows/{id}/restart`

Restart the specified bookflow, i.e. pretend that the bookflow’s original document was just uploaded and analyze it from scratch. Note that this endpoint switches the bookflow to `"processing"` until Bookalope has finished processing it.

**Parameters**: The two accepted parameters `skip_analysis` and `beeline` are the same as for the [`POST /api/bookflows/{id}/files/document`](#post-bookflows-files-document) endpoint.  
**Return**: n/a  
**Errors**: `406` if the bookflow is currently processing or had no orginal document uploaded yet. `415` if the uploaded document is in an unsupported file format.

    ~ > http --auth token: --verbose POST https://bookflow.bookalope.net/api/bookflows/d441bf24d81b4f7a849fc77359f6d775/restart
    POST /api/bookflows/d441bf24d81b4f7a849fc77359f6d775/restart HTTP/1.1
    Accept: application/json, */*
    Accept-Encoding: gzip, deflate
    Authorization: Basic token
    Connection: keep-alive
    Content-Length: 0
    Content-Type: application/json
    Host: bookflow.bookalope.net
    User-Agent: HTTPie/2.2.0

    HTTP/1.1 200 OK
    Access-Control-Expose-Headers: X-Bookalope-Version, X-Bookalope-API-Version
    Cache-Control: no-cache
    Content-Length: 4
    Content-Type: application/json
    Date: Fri, 14 Aug 2020 07:03:59 GMT
    Server: nginx/1.19.0
    X-Bookalope-Api-Version: 1.2.0
    X-Bookalope-Version: 1.5.0
    X-Content-Type-Options: nosniff

    null

<a name="get-bookflows-download-status"></a>`GET https://bookflow.bookalope.net/api/bookflows/{id}/download/{format}/status`

Get the current status of the converted document. Valid status values are `'processing'` (the document is currently converting), `'available'` (the document has been converted successfully and is ready for download), `'failed'` (the document failed to convert and can not be downloaded), and `'none'` (no conversion is available, and needs to be triggered by calling the `/convert` endpoint).

Note that the URL is the same as returned by the `/convert` endpoint!

**Parameters:** n/a  
**Return:** Information about the document’s processing status.  
**Errors:** n/a

    ~ > http --auth token: --verbose GET https://bookflow.bookalope.net/api/bookflows/d441bf24d81b4f7a849fc77359f6d775/download/ebub3/status
    GET /api/bookflows/d441bf24d81b4f7a849fc77359f6d775/download/epub3/status HTTP/1.1
    Accept: application/json, */*
    Accept-Encoding: gzip, deflate
    Authorization: Basic token
    Connection: keep-alive
    Content-Type: application/json
    Host: bookflow.bookalope.net
    User-Agent: HTTPie/0.9.8

    HTTP/1.1 200 OK
    Content-Length: 67
    Content-Type: application/json
    Date: Fri, 25 May 2018 05:21:11 GMT
    Server: nginx/1.9.7
    X-Content-Type-Options: nosniff

    {
        "download_url": "https://bookflow.bookalope.net/api/bookflows/3319a466eb7744449741dc90dd21e8ee/download/epub3",
        "status": "available"
    }

<a name="get-bookflows-download"></a>`GET https://bookflow.bookalope.net/api/bookflows/{id}/download/{format}`

Download the specified converted document.

**Parameters:** n/a  
**Return:** The converted document attachment to the response.  
**Errors:** `400` if the status of the conversion is anything else but `'available'`; `406` if the converted file is not (yet) available.

    ~ > http --auth token: --verbose --download GET https://bookflow.bookalope.net/api/bookflows/d441bf24d81b4f7a849fc77359f6d775/download/epub3
    GET /api/bookflows/d441bf24d81b4f7a849fc77359f6d775/download/epub3 HTTP/1.1
    Accept: application/json, */*
    Accept-Encoding: identity
    Authorization: Basic token
    Connection: keep-alive
    Content-Type: application/json
    Host: bookflow.bookalope.net
    User-Agent: HTTPie/0.9.8

    HTTP/1.1 200 OK
    Content-Disposition: attachment; filename="d441bf24d81b4f7a849fc77359f6d775.epub"
    Content-Length: 15980
    Content-Type: application/epub+zip
    Date: Fri, 25 May 2018 06:00:23 GMT
    Server: nginx/1.9.7
    X-Content-Type-Options: nosniff

    Downloading 15.61 kB to "d441bf24d81b4f7a849fc77359f6d775.epub"
    Done. 15.61 kB in 0.00051s (29.65 MB/s)

<a name="delete-bookflows-download"></a>`DELETE https://bookflow.bookalope.net/api/bookflows/{id}/download/{format}`

Delete the specified converted document. This is useful to change export options and convert a document again.

**Parameters:** n/a  
**Return:** n/a  
**Errors:** `406` if the file wasn’t converted yet or if it’s not yet available.

    ~ > http --verbose --auth token: DELETE https://bookflow.bookalope.net/api/bookflows/d441bf24d81b4f7a849fc77359f6d775/download/epub3
    DELETE /api/bookflows/d441bf24d81b4f7a849fc77359f6d775/download/epub3 HTTP/1.1
    Accept: */*
    Accept-Encoding: gzip, deflate
    Authorization: Basic token
    Connection: keep-alive
    Content-Length: 0
    Host: bookflow.bookalope.net
    User-Agent: HTTPie/2.2.0
    
    HTTP/1.1 204 No Content
    Access-Control-Expose-Headers: X-Bookalope-API-Version, X-Bookalope-Version
    Cache-Control: no-cache
    Connection: close
    Date: Tue, 18 Aug 2020 04:20:30 GMT
    Server: nginx/1.19.0
    X-Bookalope-Api-Version: 1.2.0
    X-Bookalope-Version: 1.5.0
    X-Content-Type-Options: nosniff