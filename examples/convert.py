#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Example of how to use the Bookalope module, a wrapper and simple object model for
the Bookalope REST API. Please read the commented code, and use the docstring
documentation of the module.
"""

import os
import sys
import argparse

import bookalope

def main():
    """
    The main and only function. Creates a Bookalope client and uses it to convert
    a given text document. The process uses Bookalope's default heuristics to
    analyse style and extract structure+content, and it uses the default visual
    styling for the generated files.
    """

    # Handle the command line arguments.
    parser = argparse.ArgumentParser()
    parser.add_argument("token", help="")
    parser.add_argument("document", help="")
    parser.add_argument("--title", dest="title", default=None, help="The title of the book.")
    parser.add_argument("--author", dest="author", default=None, help="The book author's name.")
    parser.add_argument("--cover", dest="cover", default=None, help="Cover image file.")
    args = parser.parse_args()

    # Create a new Bookalope client to communicate with the server.
    print("Creating Bookalope client...")
    b_client = bookalope.BookalopeClient()
    b_client.token = args.token

    # To convert a document, we create a new Book first and then a Bookflow for
    # that book.  A bookflow is a single conversion of a document.  Having
    # multiple bookflows per books allows us to handle multiple manuscript
    # iterations of the same book.
    print("Creating new book and bookflow...")
    book = b_client.create_book()
    bookflow = book.create_bookflow()

    # Set title and author for this bookflow, and save.
    if args.title or args.author:
        bookflow.title = args.title
        bookflow.author = args.author
        bookflow.save()

    # Upload the manuscript document.
    print("Uploading document...")
    with open(args.document, "rb") as doc:
        _, fname = os.path.split(doc.name)
        bookflow.set_document(fname, doc.read())

    # If specified, upload the cover image for the book.
    if args.cover:
        print("Uploading cover image...")
        with open(args.cover, "rb") as cover:
            _, fname = os.path.split(cover.name)
            bookflow.set_cover_image(fname, cover.read())

    # Convert and download the document. For every format that we download we
    # use the 'default' styling, and we download the 'test' version to avoid
    # charges to our credit card.
    for format_ in ["epub", "epub3", "mobi", "pdf", "icml", "docx"]:
        print("Converting and downloading " + format_ + "...")

        # Get the Style instance for the default styling.
        styles = b_client.get_styles(format_)
        default_style = next(_ for _ in styles if _.short_name == "default")
        converted_bytes = bookflow.convert(format_, default_style, version="test")

        # Save the converted document.
        fname = "{}.{}".format(bookflow.id, format_)
        with open(fname, "wb") as doc_conv:
            doc_conv.write(converted_bytes)

    # Delete the book and all of its bookflows.
    print("Deleting book and all bookflows...")
    book.delete()

    # Done.
    print("Done.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
