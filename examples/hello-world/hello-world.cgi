#!/usr/bin/perl

use Web::Simple 'HelloWorld';

{
  package HelloWorld;

  dispatch {
    sub (GET) {
      [ 200, [ 'Content-type', 'text/plain' ], [ 'Hello world!' ] ]
    },
    sub () {
      [ 405, [ 'Content-type', 'text/plain' ], [ 'Method not allowed' ] ]
    }
  };
}

HelloWorld->run_if_script;
