use strict;
use warnings FATAL => 'all';

use Test::More qw(no_plan);

use Web::Simple::DispatchParser;

my $dp = Web::Simple::DispatchParser->new;

my $get = $dp->parse_dispatch_specification('GET');

is_deeply(
  [ $get->({ REQUEST_METHOD => 'GET' }) ],
  [ {} ],
  'GET matches'
);

is_deeply(
  [ $get->({ REQUEST_METHOD => 'POST' }) ],
  [],
  'POST does not match'
);

ok(
  !eval { $dp->parse_dispatch_specification('GET POST'); 1; },
  "Don't yet allow two methods"
);

my $html = $dp->parse_dispatch_specification('.html');

is_deeply(
  [ $html->({ PATH_INFO => '/foo/bar.html' }) ],
  [ { PATH_INFO => '/foo/bar' } ],
  '.html matches'
);

is_deeply(
  [ $html->({ PATH_INFO => '/foo/bar.xml' }) ],
  [],
  '.xml does not match .html'
);

my $any_ext = $dp->parse_dispatch_specification('.*');

is_deeply(
  [ $any_ext->({ PATH_INFO => '/foo/bar.html' }) ],
  [ { PATH_INFO => '/foo/bar' }, 'html' ],
  '.html matches .* and extension returned'
);

is_deeply(
  [ $any_ext->({ PATH_INFO => '/foo/bar' }) ],
  [],
  'no extension does not match .*'
);


my $slash = $dp->parse_dispatch_specification('/');

is_deeply(
  [ $slash->({ PATH_INFO => '/' }) ],
  [ {} ],
  '/ matches /'
);

is_deeply(
  [ $slash->({ PATH_INFO => '/foo' }) ],
  [ ],
  '/foo does not match /'
);

my $post = $dp->parse_dispatch_specification('/post/*');

is_deeply(
  [ $post->({ PATH_INFO => '/post/one' }) ],
  [ {}, 'one' ],
  '/post/one parses out one'
);

is_deeply(
  [ $post->({ PATH_INFO => '/post/one/' }) ],
  [],
  '/post/one/ does not match'
);

my $combi = $dp->parse_dispatch_specification('GET+/post/*');

is_deeply(
  [ $combi->({ PATH_INFO => '/post/one', REQUEST_METHOD => 'GET' }) ],
  [ {}, 'one' ],
  '/post/one parses out one'
);

is_deeply(
  [ $combi->({ PATH_INFO => '/post/one/', REQUEST_METHOD => 'GET' }) ],
  [],
  '/post/one/ does not match'
);

is_deeply(
  [ $combi->({ PATH_INFO => '/post/one', REQUEST_METHOD => 'POST' }) ],
  [],
  'POST /post/one does not match'
);

my $or = $dp->parse_dispatch_specification('GET|POST');

foreach my $meth (qw(GET POST)) {

  is_deeply(
    [ $or->({ REQUEST_METHOD => $meth }) ],
    [ {} ],
    'GET|POST matches method '.$meth
  );
}

is_deeply(
  [ $or->({ REQUEST_METHOD => 'PUT' }) ],
  [],
  'GET|POST does not match PUT'
);

$or = $dp->parse_dispatch_specification('GET|POST|DELETE');

foreach my $meth (qw(GET POST DELETE)) {

  is_deeply(
    [ $or->({ REQUEST_METHOD => $meth }) ],
    [ {} ],
    'GET|POST|DELETE matches method '.$meth
  );
}

is_deeply(
  [ $or->({ REQUEST_METHOD => 'PUT' }) ],
  [],
  'GET|POST|DELETE does not match PUT'
);

my $nest = $dp->parse_dispatch_specification('(GET+/foo)|POST');

is_deeply(
  [ $nest->({ PATH_INFO => '/foo', REQUEST_METHOD => 'GET' }) ],
  [ {} ],
  '(GET+/foo)|POST matches GET /foo'
);

is_deeply(
  [ $nest->({ PATH_INFO => '/bar', REQUEST_METHOD => 'GET' }) ],
  [],
  '(GET+/foo)|POST does not match GET /bar'
);

is_deeply(
  [ $nest->({ PATH_INFO => '/bar', REQUEST_METHOD => 'POST' }) ],
  [ {} ],
  '(GET+/foo)|POST matches POST /bar'
);

is_deeply(
  [ $nest->({ PATH_INFO => '/foo', REQUEST_METHOD => 'PUT' }) ],
  [],
  '(GET+/foo)|POST does not match PUT /foo'
);

{
  local $@;
  ok(
    !eval { $dp->parse_dispatch_specification('/foo+(GET'); 1 },
    'Death with missing closing )'
  );
  my $err = q{
    /foo+(GET
         ^
  };
  (s/^\n//s,s/\n  $//s,s/^    //mg) for $err;
  like(
    $@,
    qr{\Q$err\E},
    "Error $@ matches\n${err}\n"
  );
}

my $not = $dp->parse_dispatch_specification('!.html+.*');

is_deeply(
  [ $not->({ PATH_INFO => '/foo.xml' }) ],
  [ { PATH_INFO => '/foo' }, 'xml' ],
  '!.html+.* matches /foo.xml'
);

is_deeply(
  [ $not->({ PATH_INFO => '/foo.html' }) ],
  [],
  '!.html+.* does not match /foo.html'
);

is_deeply(
  [ $not->({ PATH_INFO => '/foo' }) ],
  [],
  '!.html+.* does not match /foo'
);

my $sub = $dp->parse_dispatch_specification('/foo/*/...');

is_deeply(
  [ $sub->({ PATH_INFO => '/foo/1/bar' }) ],
  [ { PATH_INFO => '/bar' }, 1 ],
  '/foo/*/... matches /foo/1/bar and strips to /bar'
);

is_deeply(
  [ $sub->({ PATH_INFO => '/foo/1/' }) ],
  [ { PATH_INFO => '/' }, 1 ],
  '/foo/*/... matches /foo/1/bar and strips to /'
);

is_deeply(
  [ $sub->({ PATH_INFO => '/foo/1' }) ],
  [],
  '/foo/*/... does not match /foo/1 (no trailing /)'
);

my $q = 'foo=FOO&bar=BAR1&baz=one+two&quux=QUUX1&quux=QUUX2'
        .'&bar=BAR2&quux=QUUX3&evil=%2F';

my %all_single = (
  foo => 'FOO',
  bar => 'BAR2',
  baz => 'one two',
  quux => 'QUUX3',
  evil => '/',
);

my %all_multi = (
  foo => [ 'FOO' ],
  bar => [ qw(BAR1 BAR2) ],
  baz => [ 'one two' ],
  quux => [ qw(QUUX1 QUUX2 QUUX3) ],
  evil => [ '/' ],
);

foreach my $lose ('?foo=','?:foo=','?@foo=','?:@foo=') {
  my $foo = $dp->parse_dispatch_specification($lose);

  is_deeply(
    [ $foo->({ QUERY_STRING => '' }) ],
    [],
    "${lose} fails with no query"
  );

  is_deeply(
    [ $foo->({ QUERY_STRING => 'bar=baz' }) ],
    [],
    "${lose} fails with query missing foo key"
  );
}

foreach my $win (
  [ '?foo=' => 'FOO' ],
  [ '?:foo=' => { foo => 'FOO' } ],
  [ '?spoo~' => undef ],
  [ '?:spoo~' => {} ],
  [ '?@spoo~' => [] ],
  [ '?:@spoo~' => { spoo => [] } ],
  [ '?bar=' => 'BAR2' ],
  [ '?:bar=' => { bar => 'BAR2' } ],
  [ '?@bar=' => [ qw(BAR1 BAR2) ] ],
  [ '?:@bar=' => { bar => [ qw(BAR1 BAR2) ] } ],
  [ '?foo=&@bar=' => 'FOO', [ qw(BAR1 BAR2) ] ],
  [ '?foo=&:@bar=' => 'FOO', { bar => [ qw(BAR1 BAR2) ] } ],
  [ '?:foo=&:@bar=' => { foo => 'FOO', bar => [ qw(BAR1 BAR2) ] } ],
  [ '?:baz=&:evil=' => { baz => 'one two', evil => '/' } ],
  [ '?*' => \%all_single ],
  [ '?@*' => \%all_multi ],
  [ '?foo=&@*' => 'FOO', do { my %h = %all_multi; delete $h{foo}; \%h } ],
  [ '?:foo=&@*' => { %all_multi, foo => 'FOO' } ],
  [ '?:@bar=&*' => { %all_single, bar => [ qw(BAR1 BAR2) ] } ],
) {
  my ($spec, @res) = @$win;
  my $match = $dp->parse_dispatch_specification($spec);
#use Data::Dump::Streamer; warn Dump($match);
  is_deeply(
    [ $match->({ QUERY_STRING => $q }) ],
    [ {}, @res ],
    "${spec} matches correctly"
  );
}
