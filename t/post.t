use strict;
use warnings FATAL => 'all';

use Test::More (
  eval { require HTTP::Request::AsCGI }
    ? 'no_plan'
    : (skip_all => 'No HTTP::Request::AsCGI')
);

{
  use Web::Simple 'PostTest';
  package PostTest;
  dispatch {
    sub (%:foo=&:bar~) {
      $_[1]->{bar} ||= 'EMPTY';
      [ 200,
        [ "Content-type" => "text/plain" ],
        [ join(' ',@{$_[1]}{qw(foo bar)}) ]
      ]
    },
  }
}

use HTTP::Request::Common qw(GET POST);

my $app = PostTest->new;

sub run_request {
  my $request = shift;
  my $c = HTTP::Request::AsCGI->new($request)->setup;
  $app->run;
  $c->restore;
  return $c->response;
}

my $get = run_request(GET 'http://localhost/');

cmp_ok($get->code, '==', 404, '404 on GET');

my $no_body = run_request(POST 'http://localhost/');

cmp_ok($no_body->code, '==', 404, '404 with empty body');

my $no_foo = run_request(POST 'http://localhost/' => [ bar => 'BAR' ]);

cmp_ok($no_foo->code, '==', 404, '404 with no foo param');

my $no_bar = run_request(POST 'http://localhost/' => [ foo => 'FOO' ]);

cmp_ok($no_bar->code, '==', 200, '200 with only foo param');

is($no_bar->content, 'FOO EMPTY', 'bar defaulted');

my $both = run_request(
  POST 'http://localhost/' => [ foo => 'FOO', bar => 'BAR' ]
);

cmp_ok($both->code, '==', 200, '200 with both params');

is($both->content, 'FOO BAR', 'both params returned');
