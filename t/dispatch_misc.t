use strict;
use warnings FATAL => 'all';
no warnings::illegalproto;

use Test::More;

use HTTP::Request::Common qw(GET POST);
use Web::Dispatch;
use HTTP::Response;

my @dispatch;

{
    use Web::Simple 'MiscTest';

    package MiscTest;
    sub dispatch_request { @dispatch }
}

my $app = MiscTest->new;
sub run_request { $app->run_test_request( @_ ); }

app_is_non_plack();
plack_app_return();
broken_route_def();
array_with_sub();
array_with_no_sub();
middleware_as_only_route();
route_returns_middleware_plus_extra();
route_returns_undef();

done_testing();

sub app_is_non_plack {

    my $r = HTTP::Response->new( 999 );

    my $d = Web::Dispatch->new( app => $r );
    eval { $d->call };

    like $@, qr/No idea how we got here with HTTP::Response/,
      "Web::Dispatch dies when run with an app() that is a non-PSGI object";
    undef $@;
}

sub plack_app_return {
    {

        package FauxPlackApp;
        sub new { bless {}, $_[0] }

        sub to_app {
            return sub {
                [ 999, [], [""] ];
            };
        }
    }

    @dispatch = (
        sub (/) {
            FauxPlackApp->new;
        }
    );

    my $get = run_request( GET => 'http://localhost/' );

    cmp_ok $get->code, '==', 999,
      "when a route returns a thing that look like a Plack app, the web app redispatches to that thing";
}

sub broken_route_def {

    @dispatch = ( '/' => "" );

    my $get = run_request( GET => 'http://localhost/' );

    cmp_ok $get->code, '==', 500, "a route definition by hash that doesn't pair a sub with a route dies";
    like $get->content, qr[No idea how we got here with /], "the error message points out the broken definition";
}

sub array_with_sub {
    @dispatch = (
        sub (/) {
            [
                sub {
                    [ 999, [], [""] ];
                },
            ];
        }
    );

    eval { run_request( GET => 'http://localhost/' ) };

    like $@, qr/Can't call method "request" on an undefined value .*MockHTTP/,
"if a route returns an arrayref with a single sub in it, then that sub is returned as a response by WD, causing HTTP::Message::PSGI to choke";
}

sub array_with_no_sub {
    @dispatch = (
        sub (/) {
            ["moo"];
        }
    );

    eval { run_request( GET => 'http://localhost/' ) };

    like $@, qr/Can't call method "request" on an undefined value .*MockHTTP/,
"if a route returns an arrayref with a scalar that is not a sub, then WD returns that array out of the PSGI app (and causes HTTP::Message::PSGI to choke)";
    undef $@;
}

sub middleware_as_only_route {
    @dispatch = ( bless {}, "Plack::Middleware" );

    my $get = run_request( GET => 'http://localhost/' );

    cmp_ok $get->code, '==', 500, "a route definition consisting of only a middleware causes a bail";
    like $get->content, qr[Multiple results but first one is a middleware \(Plack::Middleware=],
      "the error message mentions the middleware class";
}

sub route_returns_middleware_plus_extra {
    @dispatch = (
        sub (/) {
            return ( bless( {}, "Plack::Middleware" ), "" );
        }
    );

    my $get = run_request( GET => 'http://localhost/' );

    cmp_ok $get->code, '==', 500, "a route returning a middleware and at least one other variable causes a bail";
    like $get->content,
      qr[Multiple results but first one is a middleware \(Plack::Middleware=],
      "the error message mentions the middleware class";
}

sub route_returns_undef {
    @dispatch = (
        sub (/) {
            (
                sub(/) {
                    undef;
                },
                sub(/) {
                    [ 900, [], [""] ];
                }
            );
        },
        sub () {
            [ 400, [], [""] ];
        }
    );

    my $get = run_request( GET => 'http://localhost/' );

    cmp_ok $get->code, '==', 900, "a route that returns undef causes WD to ignore it and resume dispatching";
}
