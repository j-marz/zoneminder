package ONVIF::PTZ::Types::Envelope;
use strict;
use warnings;


__PACKAGE__->_set_element_form_qualified(1);

sub get_xmlns { 'http://schemas.xmlsoap.org/soap/envelope/' };

our $XML_ATTRIBUTE_CLASS;
undef $XML_ATTRIBUTE_CLASS;

sub __get_attr_class {
    return $XML_ATTRIBUTE_CLASS;
}

use Class::Std::Fast::Storable constructor => 'none';
use base qw(SOAP::WSDL::XSD::Typelib::ComplexType);

Class::Std::initialize();

{ # BLOCK to scope variables

my %Header_of :ATTR(:get<Header>);
my %Body_of :ATTR(:get<Body>);

__PACKAGE__->_factory(
    [ qw(        Header
        Body

    ) ],
    {
        'Header' => \%Header_of,
        'Body' => \%Body_of,
    },
    {
        'Header' => 'ONVIF::PTZ::Elements::Header',

        'Body' => 'ONVIF::PTZ::Elements::Body',

    },
    {

        'Header' => '',
        'Body' => '',
    }
);

} # end BLOCK








1;


=pod

=head1 NAME

ONVIF::PTZ::Types::Envelope

=head1 DESCRIPTION

Perl data type class for the XML Schema defined complexType
Envelope from the namespace http://schemas.xmlsoap.org/soap/envelope/.






=head2 PROPERTIES

The following properties may be accessed using get_PROPERTY / set_PROPERTY
methods:

=over

=item * Header

Note: The name of this property has been altered, because it didn't match
perl's notion of variable/subroutine names. The altered name is used in
perl code only, XML output uses the original name:

 


=item * Body

Note: The name of this property has been altered, because it didn't match
perl's notion of variable/subroutine names. The altered name is used in
perl code only, XML output uses the original name:

 




=back


=head1 METHODS

=head2 new

Constructor. The following data structure may be passed to new():

 { # ONVIF::PTZ::Types::Envelope
   Header =>  { # ONVIF::PTZ::Types::Header
   },
   Body =>  { # ONVIF::PTZ::Types::Body
   },
 },




=head1 AUTHOR

Generated by SOAP::WSDL

=cut
