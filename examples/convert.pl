#! /usr/bin/env perl

use strict;
use warnings;
use feature qw(say);

use Getopt::Long qw(GetOptions);
use LWP::UserAgent;
use JSON qw(decode_json encode_json);
use MIME::Base64 qw(encode_base64);
use File::Slurp qw(read_file write_file);
use File::Basename;

=head1 convert.pl

Parse and handle command line arguments. The command line has the following structure:

   convert.pl [--title <book-title>] [--author <book-author>] [--cover <cover-image>] <token> <filename>

where C<--title> and C<--author> are optional arguments, I<< <token> >> is the Bookalope authentication
token, and I<< <filename> >> the document that's to be converted.

=cut

my $author = 'Author';
my $title = 'Title';
my $cover;
GetOptions(
    'author=s' => \$author,
    'title=s' => \$title,
    'cover=s' => \$cover,
) or die 'Unknown command line options';
my $token = shift or die 'Missing command line argument: token';
my $filename = shift or die 'Missing command line argument: filename';

# Helper function to make an HTTP request and handle the response. If the response
# contains a JSON encoded body, return the decoded Perl object; if the response
# contains a binary attachment, return the bytes; else return nothing.

sub make_request {
    my ($method, $url, $params) = @_;

    my $ua = LWP::UserAgent->new;
    # $ua->timeout(600);

    my $request;
    my $response;
    $request = HTTP::Request->new($method => 'https://bookflow.bookalope.net' . $url);
    $request->header('content-type' => 'application/json');
    $request->authorization_basic($token, '');
    if ($params) {
        $request->content(encode_json($params));
    }
    $response = $ua->request($request);
    if ($response->is_success) {
        if ($response->header('Content-Type') eq 'application/json; charset=UTF-8') {
            my $json_body = $response->decoded_content;
            return decode_json($json_body);
        }
        my $disp = $response->header('Content-Disposition');
        if ($disp and index($disp, 'attachment') == 0) {
            return $response->content;
        }
        return;
    }
    die 'HTTP response error ' . $response->code . ': ' . $response->message;
}

sub get_request {
    my ($url, $params) = @_;
    my $u = URI->new($url);
    $u->query_form($params);
    return make_request('GET', $u->as_string);
}

sub post_request {
    return make_request('POST', @_);
}

sub delete_request {
    return make_request('DELETE', @_);
}

# Base URL for the API.
my $api = '/api';

# Create a new book with an empty bookflow.
my $api_books = "$api/books";
my $book = post_request($api_books, {'name' => $title});
my $book_id = $book->{'book'}{'id'};
my $bookflow = $book->{'book'}{'bookflows'}[0];
my $bookflow_id = $bookflow->{'id'};
say 'Created new book ' . $book_id . ' with bookflow ' . $bookflow_id;

# Set author and title for this bookflow.
my $api_bookflows = "$api/books/$book_id/bookflows/$bookflow_id";
post_request($api_bookflows, {'name' => 'Bookflow 1', 'title' => $title, 'author' => $author});

# Upload the document.
say 'Uploading document...';
my $api_document = "$api/books/$book_id/bookflows/$bookflow_id/files/document";
post_request($api_document, {'filetype' => 'doc', 'filename' => basename($filename), 'file' => encode_base64(read_file($filename))});

# Upload the cover image, if one was given.
if ($cover) {
    say 'Uploading cover image...';
    my $api_cover = "$api/books/$book_id/bookflows/$bookflow_id/files/image";
    post_request($api_cover, {'name' => 'cover', 'filename' => basename($cover), 'file' => encode_base64(read_file($cover))});
}

# Download the converted files.
say 'Downloading converted books...';
my $api_convert = "$api/books/$book_id/bookflows/$bookflow_id/convert";
write_file($bookflow_id . '.epub', get_request($api_convert, {'format' => 'epub', 'version' => 'test'}));
write_file($bookflow_id . '.mobi', get_request($api_convert, {'format' => 'mobi', 'version' => 'test'}));
write_file($bookflow_id . '.pdf', get_request($api_convert, {'format' => 'pdf', 'version' => 'test'}));
write_file($bookflow_id . '.icml', get_request($api_convert, {'format' => 'icml', 'version' => 'test'}));
write_file($bookflow_id . '.docx', get_request($api_convert, {'format' => 'docx', 'version' => 'test'}));

# Delete the book and all of its data.
delete_request("$api/books/$book_id");
say 'Deleted book and bookflow';

# Done.
exit 0;
