use strict; use warnings FATAL => 'all';
use Test::More qw(no_plan);

{

  package Foo;

  sub foo {
    use XML::Tags qw(one two three);
    <one>, <two>, <three>;
  }

  sub bar {
    no warnings 'once'; # this is supposed to warn, it's broken
    <one>
  }

  sub baz {
    use XML::Tags qw(bar);
    </bar>;
  }

  sub quux {
    use HTML::Tags;
    <html>, <body id="spoon">, "YAY", </body>, </html>;
  }

  sub fleem {
    use XML::Tags qw(woo);
    my $ent = "one&two";
    <woo ent="$ent">;
  }

  sub globbery {
    <t/globbery/*>;
  }
}

is(
  join(', ', XML::Tags::to_xml_string Foo::foo()),
  '<one>, <two>, <three>',
  'open tags ok'
);

ok(!eval { Foo::bar(); 1 }, 'Death on use of unimported tag');

is(
  join(', ', XML::Tags::to_xml_string Foo::baz()),
  '</bar>',
  'close tag ok'
);

is(
  join('', HTML::Tags::to_html_string Foo::quux),
  '<html><body id="spoon">YAY</body></html>',
  'HTML tags ok'
);

is(
  join('', XML::Tags::to_xml_string Foo::fleem),
  '<woo ent="one&amp;two">',
  'Escaping ok'
);

is(
  join(', ', Foo::globbery),
  't/globbery/one, t/globbery/two',
  'real glob re-installed ok'
);
