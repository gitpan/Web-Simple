package Web::Simple;

use strictures 1;
use 5.008;
use warnings::illegalproto ();
use Moo ();
use Web::Dispatch::Wrapper ();

our $VERSION = '0.005';

sub import {
  my ($class, $app_package) = @_;
  $app_package ||= caller;
  $class->_export_into($app_package);
  eval "package $app_package; use Web::Dispatch::Wrapper; use Moo; 1"
    or die "Failed to setup app package: $@";
  strictures->import;
  warnings::illegalproto->unimport;
}

sub _export_into {
  my ($class, $app_package) = @_;
  {
    no strict 'refs';
    *{"${app_package}::PSGI_ENV"} = sub () { -1 };
    require Web::Simple::Application;
    unshift(@{"${app_package}::ISA"}, 'Web::Simple::Application');
  }
  (my $name = $app_package) =~ s/::/\//g;
  $INC{"${name}.pm"} = 'Set by "use Web::Simple;" invocation';
}

=head1 NAME

Web::Simple - A quick and easy way to build simple web applications

=head1 WARNING

This is really quite new. If you're reading this on CPAN, it means the stuff
that's here we're probably happy with. But only probably. So we may have to
change stuff. And if you're reading this from git, come check with irc.perl.org
#web-simple that we're actually sure we're going to keep anything that's
different from the CPAN version.

If we do find we have to change stuff we'll add to the
L<CHANGES BETWEEN RELEASES> section explaining how to switch your code across
to the new version, and we'll do our best to make it as painless as possible
because we've got Web::Simple applications too. But we can't promise not to
change things at all. Not yet. Sorry.

=head1 SYNOPSIS

  #!/usr/bin/env perl

  use Web::Simple 'HelloWorld';

  {
    package HelloWorld;

    sub dispatch_request {
      sub (GET) {
        [ 200, [ 'Content-type', 'text/plain' ], [ 'Hello world!' ] ]
      },
      sub () {
        [ 405, [ 'Content-type', 'text/plain' ], [ 'Method not allowed' ] ]
      }
    }
  }

  HelloWorld->run_if_script;

If you save this file into your cgi-bin as C<hello-world.cgi> and then visit:

  http://my.server.name/cgi-bin/hello-world.cgi/

you'll get the "Hello world!" string output to your browser. For more complex
examples and non-CGI deployment, see below. To get help with L<Web::Simple>,
please connect to the irc.perl.org IRC network and join #web-simple.

=head1 DESCRIPTION

The philosophy of L<Web::Simple> is to keep to an absolute bare minimum for
everything. It is not designed to be used for large scale applications;
the L<Catalyst> web framework already works very nicely for that and is
a far more mature, well supported piece of software.

However, if you have an application that only does a couple of things, and
want to not have to think about complexities of deployment, then L<Web::Simple>
might be just the thing for you.

The only public interface the L<Web::Simple> module itself provides is an
C<import> based one:

  use Web::Simple 'NameOfApplication';

This sets up your package (in this case "NameOfApplication" is your package)
so that it inherits from L<Web::Simple::Application> and imports L<strictures>,
as well as installs a C<PSGI_ENV> constant for convenience, as well as some 
other subroutines.

Importing L<strictures> will automatically make your code use the C<strict> and
C<warnings> pragma, so you can skip the usual:

  use strict;
  use warnings FATAL => 'aa';

provided you 'use Web::Simple' at the top of the file. Note that we turn
on *fatal* warnings so if you have any warnings at any point from the file
that you did 'use Web::Simple' in, then your application will die. This is,
so far, considered a feature.

When we inherit from L<Web::Simple::Application> we also use <Moo>, which is
the the equivalent of:

  {
    package NameOfApplication;
    use Moo;
    extends 'Web::Simple::Application';
  }

So you can use L<Moo> features in your application, such as creating attributes
using the C<has> subroutine, etc.  Please see the documentation for L<Moo> for
more information.

It also exports the following subroutines for use in dispatchers:

  response_filter { ... };

  redispatch_to '/somewhere';

Finally, import sets

  $INC{"NameOfApplication.pm"} = 'Set by "use Web::Simple;" invocation';

so that perl will not attempt to load the application again even if

  require NameOfApplication;

is encountered in other code.

=head1 DISPATCH STRATEGY

L<Web::Simple> despite being straightforward to use, has a powerful system
for matching all sorts of incoming URLs to one or more subroutines.  These
subroutines can be simple actions to take for a given URL, or something
more complicated, including entire L<Plack> applications, L<Plack::Middleware>
and nested subdispatchers.

=head2 Examples

 sub dispatch_request {
   # matches: GET /user/1.htm?show_details=1
   #          GET /user/1.htm
   sub (GET + /user/* + ?show_details~ + .htm|.html|.xhtml) {
     my ($self, $user_id, $show_details) = @_;
     ...
   },
   # matches: POST /user?username=frew
   #          POST /user?username=mst&first_name=matt&last_name=trout
   sub (POST + /user + ?username=&*) {
      my ($self, $username, $misc_params) = @_;
     ...
   },
   # matches: DELETE /user/1/friend/2
   sub (DELETE + /user/*/friend/*) {
     my ($self, $user_id, $friend_id) = @_;
     ...
   },
   # matches: PUT /user/1?first_name=Matt&last_name=Trout
   sub (PUT + /user/* + ?first_name~&last_name~) {
     my ($self, $user_id, $first_name, $last_name) = @_;
     ...
   },
   sub (/user/*/...) {
     my $user_id = $_[1];
     # matches: PUT /user/1/role/1
     sub (PUT + /role/*) {
       my $role_id = $_[1];
       ...
     },
     # matches: DELETE /user/1/role/1
     sub (DELETE + /role/*) {
       my $role_id = $_[1];
       ...
     },
   },
 }

=head2 The dispatch cycle

At the beginning of a request, your app's dispatch_request method is called
with the PSGI $env as an argument. You can handle the request entirely in
here and return a PSGI response arrayref if you want:

  sub dispatch_request {
    my ($self, $env) = @_;
    [ 404, [ 'Content-type' => 'text/plain' ], [ 'Amnesia == fail' ] ]
  }

However, generally, instead of that, you return a set of dispatch subs:

  sub dispatch_request {
    my $self = shift;
    sub (/) { redispatch_to '/index.html' },
    sub (/user/*) { $self->show_user($_[1]) },
    ...
  }

If you return a subroutine with a prototype, the prototype is treated
as a match specification - and if the test is passed, the body of the
sub is called as a method any matched arguments (see below for more details).

You can also return a plain subroutine which will be called with just $env
- remember that in this case if you need $self you -must- close over it.

If you return a normal object, L<Web::Simple> will simply return it upwards on
the assumption that a response_filter (or some arbitrary L<Plack::Middleware>)
somewhere will convert it to something useful.  This allows:

  sub dispatch_request {
    my $self = shift;
    sub (.html) { response_filter { $self->render_zoom($_[0]) } },
    sub (/user/*) { $self->users->get($_[1]) },
  }

to render a user object to HTML, if there is an incoming URL such as:

  http://myweb.org/user/111.html

This works because as we descend down the dispachers, we first match
C<sub (.html)>, which adds a C<response_filter> (basically a specialized routine
that follows the L<Plack::Middleware> specification), and then later we also
match C<sub (/user/*)> which gets a user and returns that as the response.
This user object 'bubbles up' through all the wrapping middleware until it hits
the C<response_filter> we defined, after which the return is converted to a
true html response.

However, two types of object are treated specially - a Plack::App object
will have its C<->to_app> method called and be used as a dispatcher:

  sub dispatch_request {
    my $self = shift;
    sub (/static/...) { Plack::App::File->new(...) },
    ...
  }

A Plack::Middleware object will be used as a filter for the rest of the
dispatch being returned into:

  ## responds to /admin/track_usage AND /admin/delete_accounts

  sub dispatch_request {
    my $self = shift;
    sub (/admin/**) {
      Plack::Middleware::Session->new(%opts);
    },
    sub (/admin/track_usage) {
      ## something that needs a session
    },
    sub (/admin/delete_accounts) {
      ## something else that needs a session
    },
  }

Note that this is for the dispatch being -returned- to, so if you want to
provide it inline you need to do:

  ## ALSO responds to /admin/track_usage AND /admin/delete_accounts

  sub dispatch_request {
    my $self = shift;
    sub (/admin/...) {
      sub {
        Plack::Middleware::Session->new(%opts);
      },
      sub (/track_usage) {
        ## something that needs a session
      },
      sub (/delete_accounts) {
        ## something else that needs a session
      },
    }
  }

And that's it - but remember that all this happens recursively - it's
dispatchers all the way down.  A URL incoming pattern will run all matching
dispatchers and then hit all added filters or L<Plack::Middleware>.

=head2 Web::Simple match specifications

=head3 Method matches

  sub (GET) {

A match specification beginning with a capital letter matches HTTP requests
with that request method.

=head3 Path matches

  sub (/login) {

A match specification beginning with a / is a path match. In the simplest
case it matches a specific path. To match a path with a wildcard part, you
can do:

  sub (/user/*) {
    $self->handle_user($_[1])

This will match /user/<anything> where <anything> does not include a literal
/ character. The matched part becomes part of the match arguments. You can
also match more than one part:

  sub (/user/*/*) {
    my ($self, $user_1, $user_2) = @_;

  sub (/domain/*/user/*) {
    my ($self, $domain, $user) = @_;

and so on. To match an arbitrary number of parts, use -

  sub (/page/**) {

This will result in an element per /-separated part so matched. Note that
you can do

  sub (/page/**/edit) {

to match an arbitrary number of parts up to but not including some final
part.

Finally,

  sub (/foo/...) {

Will match /foo/ on the beginning of the path -and- strip it. This is designed
to be used to construct nested dispatch structures, but can also prove useful
for having e.g. an optional language specification at the start of a path.

Note that the '...' is a "maybe something here, maybe not" so the above
specification will match like this:

  /foo         # no match
  /foo/        # match and strip path to '/'
  /foo/bar/baz # match and strip path to '/bar/baz'

=head3 Extension matches

  sub (.html) {

will match .html from the path (assuming the subroutine itself returns
something, of course). This is normally used for rendering - e.g.

  sub (.html) {
    response_filter { $self->render_html($_[1]) }
  }

Additionally,

  sub (.*) {

will match any extension and supplies the extension as a match argument.

=head3 Query and body parameter matches

Query and body parameters can be match via

  sub (?<param spec>) { # match URI query
  sub (%<param spec>) { # match body params

The body is only matched if the content type is
application/x-www-form-urlencoded (note this means that Web::Simple does
not yet handle uploads; this will be addressed in a later release).

The param spec is elements of one of the following forms -

  param~        # optional parameter
  param=        # required parameter
  @param~       # optional multiple parameter
  @param=       # required multiple parameter
  :param~       # optional parameter in hashref
  :param=       # required parameter in hashref
  :@param~      # optional multiple in hashref
  :@param=      # required multiple in hashref
  *             # include all other parameters in hashref
  @*            # include all other parameters as multiple in hashref

separated by the & character. The arguments added to the request are
one per non-:/* parameter (scalar for normal, arrayref for multiple),
plus if any :/* specs exist a hashref containing those values.

Please note that if you specify a multiple type parameter match, you are
ensured of getting an arrayref for the value, EVEN if the current incoming
request has only one value.  However if a parameter is specified as single
and multiple values are found, the last one will be used.

For example to match a page parameter with an optional order_by parameter one
would write:

  sub (?page=&order_by~) {
    my ($self, $page, $order_by) = @_;
    return unless $page =~ /^\d+$/;
    $page ||= 'id';
    response_filter {
      $_[1]->search_rs({}, $p);
    }
  }

to implement paging and ordering against a L<DBIx::Class::ResultSet> object.

Another Example: To get all parameters as a hashref of arrayrefs, write:

  sub(?@*) {
    my ($self, $params) = @_;
    ...

To get two parameters as a hashref, write:

  sub(?:user~&:domain~) {
    my ($self, $params) = @_; # params contains only 'user' and 'domain' keys

You can also mix these, so:

  sub (?foo=&@bar~&:coffee=&@*) {
     my ($self, $foo, $bar, $params);

where $bar is an arrayref (possibly an empty one), and $params contains
arrayref values for all parameters -not- mentioned and a scalar value for
the 'coffee' parameter.

Note, in the case where you combine arrayref, single parameter and named
hashref style, the arrayref and single parameters will appear in C<@_> in the
order you defined them in the protoype, but all hashrefs will merge into a 
single C<$params>, as in the example above.

=head3 Combining matches

Matches may be combined with the + character - e.g.

  sub (GET + /user/*) {

to create an AND match. They may also be combined withe the | character - e.g.

  sub (GET|POST) {

to create an OR match. Matches can be nested with () - e.g.

  sub ((GET|POST) + /user/*) {

and negated with ! - e.g.

  sub (!/user/foo + /user/*) {

! binds to the immediate rightmost match specification, so if you want
to negate a combination you will need to use

  sub ( !(POST|PUT|DELETE) ) {

and | binds tighter than +, so

  sub ((GET|POST) + /user/*) {

and

  sub (GET|POST + /user/*) {

are equivalent, but

  sub ((GET + /admin/...) | (POST + /admin/...)) {

and

  sub (GET + /admin/... | POST + /admin/...) {

are not - the latter is equivalent to

  sub (GET + (/admin/...|POST) + /admin/...) {

which will never match!

=head3 Whitespace

Note that for legibility you are permitted to use whitespace -

  sub (GET + /user/*) {

but it will be ignored. This is because the perl parser strips whitespace
from subroutine prototypes, so this is equivalent to

  sub (GET+/user/*) {

=head3 Accessing the PSGI env hash

In some cases you may wish to get the raw PSGI env hash - to do this,
you can either use a plain sub -

  sub {
    my ($env) = @_;
    ...
  }

or use the PSGI_ENV constant exported to retrieve it:

  sub (GET + /foo + ?some_param=) {
    my $param = $_[1];
    my $env = $_[PSGI_ENV];
  }

but note that if you're trying to add a middleware, you should simply use
Web::Simple's direct support for doing so.

=head1 EXPORTED SUBROUTINES

=head2 response_filter

  response_filter {
    # Hide errors from the user because we hates them, preciousss
    if (ref($_[0]) eq 'ARRAY' && $_[0]->[0] == 500) {
      $_[0] = [ 200, @{$_[0]}[1..$#{$_[0]}] ];
    }
    return $_[0];
  };

The response_filter subroutine is designed for use inside dispatch subroutines.

It creates and returns a special dispatcher that always matches, and calls
the block passed to it as a filter on the result of running the rest of the
current dispatch chain.

Thus the filter above runs further dispatch as normal, but if the result of
dispatch is a 500 (Internal Server Error) response, changes this to a 200 (OK)
response without altering the headers or body.

=head2 redispatch_to

  redispatch_to '/other/url';

The redispatch_to subroutine is designed for use inside dispatch subroutines.

It creates and returns a special dispatcher that always matches, and instead
of continuing dispatch re-delegates it to the start of the dispatch process,
but with the path of the request altered to the supplied URL.

Thus if you receive a POST to '/some/url' and return a redispatch to
'/other/url', the dispatch behaviour will be exactly as if the same POST
request had been made to '/other/url' instead.

Note, this is not the same as returning an HTTP 3xx redirect as a response;
rather it is a much more efficient internal process.  

=head1 CHANGES BETWEEN RELEASES

=head2 Changes between 0.004 and 0.005

=over 4

=item * dispatch {} replaced by declaring a dispatch_request method

dispatch {} has gone away - instead, you write:

  sub dispatch_request {
    my $self = shift;
    sub (GET /foo/) { ... },
    ...
  }

Note that this method is still -returning- the dispatch code - just like
dispatch did.

Also note that you need the 'my $self = shift' since the magic $self
variable went away.

=item * the magic $self variable went away.

Just add 'my $self = shift;' while writing your 'sub dispatch_request {'
like a normal perl method.

=item * subdispatch deleted - all dispatchers can now subdispatch

In earlier releases you needed to write:

  subdispatch sub (/foo/...) {
    ...
    [
      sub (GET /bar/) { ... },
      ...
    ]
  }

As of 0.005, you can instead write simply:

  sub (/foo/...) {
    ...
    (
      sub (GET /bar/) { ... },
      ...
    )
  }

=head2 Changes since Antiquated Perl

=over 4

=item * filter_response renamed to response_filter

This is a pure rename; a global search and replace should fix it.

=item * dispatch [] changed to dispatch {}

Simply changing

  dispatch [ sub(...) { ... }, ... ];

to

  dispatch { sub(...) { ... }, ... };

should work fine.

=back

=head1 DEVELOPMENT HISTORY

Web::Simple was originally written to form part of my Antiquated Perl talk for
Italian Perl Workshop 2009, but in writing the bloggery example I realised
that having a bare minimum system for writing web applications that doesn't
drive me insane was rather nice and decided to spend my attempt at nanowrimo
for 2009 improving and documenting it to the point where others could use it.

The Antiquated Perl talk can be found at L<http://www.shadowcat.co.uk/archive/conference-video/>.

=head1 COMMUNITY AND SUPPORT

=head2 IRC channel

irc.perl.org #web-simple

=head2 No mailing list yet

Because mst's non-work email is a bombsite so he'd never read it anyway.

=head2 Git repository

Gitweb is on http://git.shadowcat.co.uk/ and the clone URL is:

  git clone git://git.shadowcat.co.uk/catagits/Web-Simple.git

=head1 AUTHOR

Matt S. Trout <mst@shadowcat.co.uk>

=head1 CONTRIBUTORS

None required yet. Maybe this module is perfect (hahahahaha ...).

=head1 COPYRIGHT

Copyright (c) 2010 the Web::Simple L</AUTHOR> and L</CONTRIBUTORS>
as listed above.

=head1 LICENSE

This library is free software and may be distributed under the same terms
as perl itself.

=cut

1;
