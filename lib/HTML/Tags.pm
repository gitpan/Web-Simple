package HTML::Tags;

use strict;
use warnings FATAL => 'all';
use XML::Tags ();

my @HTML_TAGS = qw(
        h1 h2 h3 h4 h5 h6 p br hr ol ul li dl dt dd menu code var strong em tt
        u i b blockquote pre img a address cite samp dfn html head base body
        link nextid title meta kbd start_html end_html input select option
        comment charset escapehtml div table caption th td tr tr sup sub
        strike applet param nobr embed basefont style span layer ilayer font
        frameset frame script small big area map abbr acronym bdo col colgroup
        del fieldset iframe ins label legend noframes noscript object optgroup
        q thead tbody tfoot blink fontsize center textfield textarea filefield
        password_field hidden checkbox checkbox_group submit reset defaults
        radio_group popup_menu button autoescape scrolling_list image_button
        start_form end_form startform endform start_multipart_form
        end_multipart_form isindex tmpfilename uploadinfo url_encoded
        multipart form canvas
);

sub import {
  my ($class, @rest) = @_;
  my $opts = ref($rest[0]) eq 'HASH' ? shift(@rest) : {};
  ($opts->{into_level}||=1)++;
  XML::Tags->import($opts, @HTML_TAGS, @rest);
}

sub to_html_string { XML::Tags::to_xml_string(@_) }

1;
