use strict;
use warnings FATAL => 'all';

use Test::More 'no_plan';
use Plack::Test;

{
  use Web::Simple 'EnvTest';
  package EnvTest;
  sub dispatch_request  {
    sub (GET) {
      my $env = $_[PSGI_ENV];
      [ 200,
        [ "Content-type" => "text/plain" ],
        [ 'foo' ]
      ]
    },
  }
}

use HTTP::Request::Common qw(GET POST);

my $app = EnvTest->new;

sub run_request {
  my $request = shift;
  return test_psgi $app->to_psgi_app, sub { shift->($request) };
}

ok run_request(GET 'http://localhost/')->is_success;
