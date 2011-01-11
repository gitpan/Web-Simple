package Web::Simple::Application;

use Moo;

has 'config' => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    +{ $self->default_config }
  },
  trigger => sub {
    my ($self, $value) = @_;
    my %default = $self->default_config;
    my @not = grep !exists $value->{$_}, keys %default;
    @{$value}{@not} = @default{@not};
  }
);

sub default_config { () }

has '_dispatcher' => (is => 'lazy');

sub _build__dispatcher {
  my $self = shift;
  require Web::Dispatch;
  require Web::Simple::DispatchNode;
  my $final = $self->_build_final_dispatcher;
  Web::Dispatch->new(
    app => sub { $self->dispatch_request(@_), $final },
    node_class => 'Web::Simple::DispatchNode',
    node_args => { app_object => $self }
  );
}

sub _build_final_dispatcher {
  [ 404, [ 'Content-type', 'text/plain' ], [ 'Not found' ] ]
}

sub run_if_script {
  # ->to_psgi_app is true for require() but also works for plackup
  return $_[0]->to_psgi_app if caller(1);
  my $self = ref($_[0]) ? $_[0] : $_[0]->new;
  $self->run(@_);
}

sub _run_cgi {
  my $self = shift;
  require Plack::Server::CGI;
  Plack::Server::CGI->run($self->to_psgi_app);
}

sub _run_fcgi {
  my $self = shift;
  require Plack::Server::FCGI;
  Plack::Server::FCGI->run($self->to_psgi_app);
}

sub to_psgi_app {
  my $self = ref($_[0]) ? $_[0] : $_[0]->new;
  $self->_dispatcher->to_app;
}

sub run {
  my $self = shift;
  if ($ENV{PHP_FCGI_CHILDREN} || $ENV{FCGI_ROLE} || $ENV{FCGI_SOCKET_PATH}) {
    return $self->_run_fcgi;
  } elsif ($ENV{GATEWAY_INTERFACE}) {
    return $self->_run_cgi;
  }
  unless (@ARGV && $ARGV[0] =~ m{^/}) {
    return $self->_run_cli(@ARGV);
  }

  my $path = shift @ARGV;

  require HTTP::Request::Common;
  require Plack::Test;
  local *GET = \&HTTP::Request::Common::GET;

  my $request = GET($path);
  my $response;
  Plack::Test::test_psgi($self->to_psgi_app, sub { $response = shift->($request) });
  print $response->as_string;
}

sub _run_cli {
  my $self = shift;
  die $self->_cli_usage;
}

sub _cli_usage {
  "To run this script in CGI test mode, pass a URL path beginning with /:\n".
  "\n".
  "  $0 /some/path\n".
  "  $0 /\n"
}

1;

=head1 NAME

Web::Simple::Application - A base class for your Web-Simple application

=head1 DESCRIPTION

This is a base class for your L<Web::Simple> application.  You probably don't
need to construct this class yourself, since L<Web::Simple> does the 'heavy
lifting' for you in that regards.

=head1 METHODS

This class exposes the following public methods.

=head2 default_config

Merges with the C<config> initializer to provide configuration information for
your application.  For example:

  sub default_config {
    (
      title => 'Bloggery',
      posts_dir => $FindBin::Bin.'/posts',
    );
  }

Now, the C<config> attribute of C<$self>  will be set to a HashRef
containing keys 'title' and 'posts_dir'.

The keys from default_config are merged into any config supplied, so
if you construct your application like:

  MyWebSimpleApp::Web->new(
    config => { title => 'Spoon', environment => 'dev' }
  )

then C<config> will contain:

  {
    title => 'Spoon',
    posts_dir => '/path/to/myapp/posts',
    environment => 'dev'
  }

=head2 run_if_script

The run_if_script method is designed to be used at the end of the script
or .pm file where your application class is defined - for example:

  ## my_web_simple_app.pl
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

This returns a true value, so your file is now valid as a module - so

  require 'my_web_simple_app.pl';

  my $hw = HelloWorld->new;

will work fine (and you can rename it to lib/HelloWorld.pm later to make it
a real use-able module).

However, it detects if it's being run as a script (via testing $0) and if
so attempts to do the right thing.

If run under a CGI environment, your application will execute as a CGI.

If run under a FastCGI environment, your application will execute as a
FastCGI process (this works both for dynamic shared-hosting-style FastCGI
and for apache FastCgiServer style setups).

If run from the commandline with a URL path, it runs a GET request against
that path -

  $ perl -Ilib examples/hello-world/hello-world.cgi /
  200 OK
  Content-Type: text/plain
  
  Hello world!

Additionally, you can treat the file as though it were a standard PSGI
application file (*.psgi).  For example you can start up up with C<plackup>

  plackup my_web_simple_app.pl

or C<starman>

  starman my_web_simple_app.pl

=head2 to_psgi_app

This method is called by L</run_if_script> to create the L<PSGI> app coderef
for use via L<Plack> and L<plackup>. If you want to globally add middleware,
you can override this method:

  use Web::Simple 'HelloWorld';
  use Plack::Builder;
 
  {
    package HelloWorld;

  
    around 'to_psgi_app', sub {
      my ($orig, $self) = (shift, shift);
      my $app = $self->$orig(@_); 
      builder {
        enable ...; ## whatever middleware you want
        $app;
      };
    };
  }

This method can also be used to mount a Web::Simple application within
a separate C<*.psgi> file -

  use strictures 1;
  use Plack::Builder;
  use WSApp;
  use AnotherWSApp;

  builder {
    mount '/' => WSApp->to_psgi_app;
    mount '/another' => AnotherWSApp->to_psgi_app;
  };

This method can be called as a class method, in which case it implicitly
calls ->new, or as an object method ... in which case it doesn't.

=head2 run

Used for running your application under stand-alone CGI and FCGI modes. Also
useful for testing:

    my $app = MyWebSimpleApp::Web->new;
    my $c = HTTP::Request::AsCGI->new(@args)->setup;
    $app->run;

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
