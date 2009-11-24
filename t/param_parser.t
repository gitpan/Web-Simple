use strict;
use warnings FATAL => 'all';

use Test::More qw(no_plan);

use Web::Simple::ParamParser;

my $param_sample = 'foo=bar&baz=quux&foo=%2F';
my $unpacked = {
  baz => [
    "quux"
  ],
  foo => [
    "bar",
    "/"
  ]
};

is_deeply(
  Web::Simple::ParamParser::_unpack_params('foo=bar&baz=quux&foo=%2F'),
  $unpacked,
  'Simple unpack ok'
);

my $env = { 'QUERY_STRING' => $param_sample };

is_deeply(
  Web::Simple::ParamParser::get_unpacked_query_from($env),
  $unpacked,
  'Dynamic unpack ok'
);

is_deeply(
  $env->{+Web::Simple::ParamParser::UNPACKED_QUERY},
  $unpacked,
  'Unpack cached ok'
);

1;
