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
import time
import asyncio

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

    # To convert a document, we create a new Book first with an empty Bookflow.
    # A bookflow is a single conversion of a document.  Having multiple
    # bookflows per books allows us to handle multiple manuscript iterations of
    # the same book.
    print("Creating new book and bookflow...")
    book = b_client.create_book()
    bookflow = book.bookflows[0]

    # If we've purchased a plan through the Bookalope website, then we can now
    # credit this Bookflow, thus getting access to the full version of the book.
    bookflow.set_credit("pro")  # Or 'basic', depending on the plan.

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

    # Wait for analysis of the uploaded document to finish.
    print("Waiting for bookflow to finish analyzing...")
    while bookflow.processing:
        time.sleep(5)
        bookflow.update()
    if bookflow.step == "processing_failed":
        print("Failed to analyze document, exiting")
        return 1

    # If specified, upload the cover image for the book.
    if args.cover:
        print("Uploading cover image...")
        with open(args.cover, "rb") as cover:
            _, fname = os.path.split(cover.name)
            bookflow.set_cover_image(fname, cover.read())

    # Get a list of all supported export file name extensions. Bookalope accepts
    # them as arguments to specify the target file format for conversion.
    formats = [format_.name for format_ in b_client.get_export_formats()]

    # Asynchronous coroutine that converts the bookflow's file to the given format.
    async def _convert_and_save(format_):
        """Coroutine to convert the bookflow's file to the given format."""
        print(f"Converting and downloading {format_}...")

        # Get the Style instance for the default styling, test version, and trigger conversion.
        styles = b_client.get_styles(format_)
        default_style = next(_ for _ in styles if _.short_name == "default")
        version = "test"
        bookflow.convert(format_, default_style, version)

        # Wait for the conversion to finish.
        while True:
            status = bookflow.convert_status(format_, default_style, version)
            if status == "processing":
                await asyncio.sleep(5)
                continue
            if status == "ok":
                break
            print(f"Conversion of {format_} failed, skipping...")
            return 1

        # Save the converted document.
        fname = f"{bookflow.id}.{format_}"
        with open(fname, "wb") as f:
            fbytes = bookflow.convert_download(format_, default_style, version)
            f.write(fbytes)
        return 0

    # Convert and download the document. For every format that we download we
    # use the 'default' styling, and we download the 'test' version to avoid
    # charges to our credit card.
    loop = asyncio.new_event_loop()
    future = asyncio.gather(*[_convert_and_save(format_) for format_ in formats], loop=loop)
    results = loop.run_until_complete(future)
    loop.close()

    # Delete the book and all of its bookflows.
    print("Deleting book and all bookflows...")
    book.delete()

    # Done.
    print("Done.")
    return 0


if __name__ == "__main__":
    assert sys.version_info >= (3, 6)
    sys.exit(main())
