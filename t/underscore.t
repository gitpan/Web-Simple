use Web::Simple 'TestApp';
use Test::More;

sub TestApp::dispatch_request {
  sub (GET + ?*) {
    [ 200, [ 'Content-type' => 'text/plain' ], [ $_{foo} ] ]
  }
}

my $res = TestApp->new->run_test_request(GET => '/?foo=bar');

is($res->content, 'bar', '%_ set ok');

done_testing;
