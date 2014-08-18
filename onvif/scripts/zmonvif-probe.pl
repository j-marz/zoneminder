#!/usr/bin/perl -w
#
# ==========================================================================
#
# ZoneMinder ONVIF Control Protocol Module
# Copyright (C) Jan M. Hochstein
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
#
# ==========================================================================
#
# This module contains the implementation of the ONVIF capability prober
#

require ONVIF::Client;

require WSDiscovery::Interfaces::WSDiscovery::WSDiscoveryPort;
require WSDiscovery::Elements::Types;
require WSDiscovery::Elements::Scopes;

require WSDiscovery::TransportUDP;

# 
# ========================================================================
# Globals

my $verbose = 0;
my $client;

# =========================================================================
# internal functions 

sub deserialize_message
{
  my ($wsdl_client, $response) = @_;

  # copied and adapted from SOAP::WSDL::Client

    # get deserializer
    my $deserializer = $wsdl_client->get_deserializer();

    if(! $deserializer) {
      $deserializer = SOAP::WSDL::Factory::Deserializer->get_deserializer({
        soap_version => $wsdl_client->get_soap_version(),
        %{ $wsdl_client->get_deserializer_args() },
      });
    }
    # set class resolver if serializer supports it
    $deserializer->set_class_resolver( $wsdl_client->get_class_resolver() )
        if ( $deserializer->can('set_class_resolver') );
          
    # Try deserializing response - there may be some,
    # even if transport did not succeed (got a 500 response)
    if ( $response ) {
        # as our faults are false, returning a success marker is the only
        # reliable way of determining whether the deserializer succeeded.
        # Custom deserializers may return an empty list, or undef,
        # and $@ is not guaranteed to be undefined.
        my ($success, $result_body, $result_header) = eval {
            (1, $deserializer->deserialize( $response ));
        };
        if (defined $success) {
            return wantarray
                ? ($result_body, $result_header)
                : $result_body;
        }
        elsif (blessed $@) { #}&& $@->isa('SOAP::WSDL::SOAP::Typelib::Fault11')) {
            return $@;
        }
        else {
            return $deserializer->generate_fault({
                code => 'soap:Server',
                role => 'urn:localhost',
                message => "Error deserializing message: $@. \n"
                    . "Message was: \n$response"
            });
        }
    };
}


sub interpret_messages
{
  my ($svc_discover, @responses, %services) = @_;

  foreach my $response ( @responses ) {

    if($verbose) {
      print "Received message:\n" . $response . "\n";
    }

    my $result = deserialize_message($svc_discover, $response);
    if(not $result) {
      if($verbose) {
        print "Error deserializing message:\n" . $result . "\n";
      }
      next;
    }

    my $xaddr;  
    foreach my $l_xaddr (split ' ', $result->get_ProbeMatch()->get_XAddrs()) {
  #   find IPv4 address
      if($l_xaddr =~ m|//[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/|) { 
        $xaddr = $l_xaddr;
        last;
      }
    }

    # ignore multiple responses from one service
    next if defined $services{$xaddr};
    $services{$xaddr} = 1;

    print "$xaddr, " . $svc_discover->get_soap_version() . ", ";

    print "(";
    my $scopes = $result->get_ProbeMatch()->get_Scopes();
    my $count = 0;
    foreach my $scope(split ' ', $scopes) {
      if($scope =~ m|onvif://www\.onvif\.org/(.+)/(.*)|) {
        my ($attr, $value) = ($1,$2);
        if( 0 < $count ++) {
          print ", ";
        }
        print $attr . "=\'" . $value . "\'";
      }
    }
    print ")\n";
  }
}

# =========================================================================
# functions 

sub discover
{
  ## collect all responses
  my @responses = ();

  no warnings 'redefine';

  *WSDiscovery::TransportUDP::_notify_response = sub {
    my ($transport, $response) = @_;
    push @responses, $response;
  };

  ## try both soap versions
  my %services;

  if($verbose) {
    print "Probing for SOAP 1.1\n"
  }
  my $svc_discover = WSDiscovery::Interfaces::WSDiscovery::WSDiscoveryPort->new({ 
#    no_dispatch => '1',
  });
  $svc_discover->set_soap_version('1.1');

  my $result = $svc_discover->ProbeOp(
    { # WSDiscovery::Types::ProbeType
      Types => { 'dn:NetworkVideoTransmitter', 'tds:Device' }, # QNameListType
      Scopes =>  { value => '' },
    },, 
  );
#  print $result . "\n";

  interpret_messages($svc_discover, \@responses, \%services);
  @responses = ();

  if($verbose) {
    print "Probing for SOAP 1.2\n"
  }
  $svc_discover = WSDiscovery::Interfaces::WSDiscovery::WSDiscoveryPort->new({
#    no_dispatch => '1',
  });
  $svc_discover->set_soap_version('1.2');

  $result = $svc_discover->ProbeOp(
    { # WSDiscovery::Types::ProbeType
      Types => { 'dn:NetworkVideoTransmitter', 'tds:Device' }, # QNameListType
      Scopes =>  { value => '' },
    },, 
  );
#  print $result . "\n";

  interpret_messages($svc_discover, @responses, \%services);
}


sub profiles
{
#  my $result = $services{media}{ep}->GetVideoSources( { } ,, );
#  die $result if not $result;
#  print $result . "\n";

  my $result = $client->get_endpoint('media')->GetProfiles( { } ,, );
  die $result if not $result;
  if($verbose) {
    print "Received message:\n" . $result . "\n";
  }

 my $profiles = $result->get_Profiles();

 foreach  my $profile ( @{ $profiles } ) {
 
   my $token = $profile->attr()->get_token() ;
   print $token . ", " . 
         $profile->get_Name() . ", " .
         $profile->get_VideoEncoderConfiguration()->get_Encoding() . ", " .
         $profile->get_VideoEncoderConfiguration()->get_Resolution()->get_Width() . ", " .
         $profile->get_VideoEncoderConfiguration()->get_Resolution()->get_Height() . ", " .
         $profile->get_VideoEncoderConfiguration()->get_RateControl()->get_FrameRateLimit() .
         ", ";

    $result = $client->get_endpoint('media')->GetStreamUri( { 
      StreamSetup =>  { # ONVIF::Media::Types::StreamSetup
        Stream => 'RTP_unicast', # StreamType
        Transport =>  { # ONVIF::Media::Types::Transport
          Protocol => 'RTSP', # TransportProtocol
        },
      },
      ProfileToken => $token, # ReferenceToken  
    } ,, );
    die $result if not $result;
  #  print $result . "\n";

    print $result->get_MediaUri()->get_Uri() .
          "\n";
 }

#
# use message parser without schema validation ???
#

}

sub move
{
  my ($dir) = @_;

  
  my $result = $client->get_endpoint('ptz')->GetNodes( { } ,, );
  
  die $result if not $result;
  print $result . "\n";

}

sub metadata
{
  my $result = $client->get_endpoint('media')->GetMetadataConfigurations( { } ,, );
  die $result if not $result;
  print $result . "\n";

  $result = $client->get_endpoint('media')->GetVideoAnalyticsConfigurations( { } ,, );
  die $result if not $result;
  print $result . "\n";

#  $result = $client->get_endpoint('analytics')->GetServiceCapabilities( { } ,, );
#  die $result if not $result;
#  print $result . "\n";
   
}

# ========================================================================
# MAIN

my $action = shift;

if($ARGV[0] eq "-v") {
  shift;
  $verbose = 1;
}

if($action eq "probe") {
  discover();
}
else {
# all other actions need URI and credentials
  my $url_svc_device = shift;
  my $soap_version = shift;
  my $username = shift;
  my $password = shift;

  $client = ONVIF::Client->new( { 
      'url_svc_device' => $url_svc_device, 
      'soap_version' => $soap_version } );

  $client->set_credentials($username, $password, 1);
  
  $client->create_services();

  
  if($action eq "profiles") {
    
    profiles();
  }
  elsif($action eq "move") {
    my $dir = shift;
    move($dir);
  }
  elsif($action eq "metadata") {
    metadata();
  }
  else {
    print("Error: Unknown command\"$action\"");
    exit(1);
  }
}
