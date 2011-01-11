use strict;
use warnings FATAL => 'all';

use Test::More (
  eval { require HTTP::Request::AsCGI }
    ? 'no_plan'
    : (skip_all => 'No HTTP::Request::AsCGI')
);

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
  my $c = HTTP::Request::AsCGI->new($request)->setup;
  $app->run;
  $c->restore;
  return $c->response;
}

ok run_request(GET 'http://localhost/')->is_success;
