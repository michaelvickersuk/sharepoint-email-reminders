#!/usr/bin/perl -w

# Michael Vickers
# 03/05/2016
# Parses an RSS file containing a timetable of Safety Conversation events and emails the participant if the event occurs today
# SharePoint setup notes for RSS file used below:
#  Document library RSS setting will require amending to increase the max item limit and max day limits
#  Create a personal view using the Active Directory account used to log into the SharePoint site, to prevent accidental changes to a public view

# m h dom mon dow user  command
#0 8 * * * perl /etc/scripts/sconsendreminder.pl >> /var/log/sconsendreminder.log 2>&1

use strict;
use warnings;
use 5.010;
#use diagnoistics;

no Carp::Assert;                   # Change "no" to "use" on this line and below for debugging purposes
no Carp::Assert::More;
use Try::Tiny;
use Time::Piece;
use XML::FeedPP;
use Email::Sender::Simple qw(sendmail);
use Email::Sender::Transport::SMTP;
use Email::Simple;
use Email::Simple::Creator;
use Email::MIME::CreateHTML;

my $items = 0;
my $emails = 0;
my $today = Time::Piece->new;

say $today->datetime . ": Starting";

my $rss = `curl --anyauth --user 'UK\\USER-NAME:pa55w0rd' 'http://sharepoint.eu.example.com/sites/longcorp/normills/_layouts/listfeed.aspx?List=cbd459c3-2e5a-4cea-bb76-1b5ac0b1f6f2&View=a48235a0-fe96-4878-897c-74c896d895e3'`;


if($rss eq "" || substr($rss, 0, 5) eq "<HTML") {
  warn "RSS Feed is unavailable";
  exit 1;
}

assert_is(substr($rss, 3, 5), "<?xml") if DEBUG;         # substr begins from character 3 as the first few characters in the file are whitespace

my $feed = XML::FeedPP->new($rss);                        # Read RSS file containing all timetabled Safety Conversations

local $/ = undef;
open FILE, "/etc/scripts/emailtemplate_scondue.html" or die "Couldn't open file: $!";
my $messagetemplate = <FILE>;                              # Load email message template
close FILE;

assert_nonblank($messagetemplate) if DEBUG;

my $transport = Email::Sender::Transport::SMTP->new({
  host => 'tssmtp.pc.teesside.eu.example.com',
  port => 25,
});

foreach my $item($feed->get_item()) {
  assert_is(get_value("Safety Conversation", $item->description()), "") if DEBUG;
  assert_is(get_value("Management of Work Audit", $item->description()), "") if DEBUG;
  assert_is(get_value("BHSI 1014c Audit", $item->description()), "") if DEBUG;
  assert_nonblank(get_value("Start Time", $item->description())) if DEBUG;
  assert_nonblank(get_value("End Time", $item->description())) if DEBUG;
  assert_nonblank(get_value("Participant", $item->description())) if DEBUG;
  assert_nonblank(get_value("Area", $item->description())) if DEBUG;
  assert_nonblank(get_value("E-Mail", $item->description())) if DEBUG;
  assert_nonblank($item->link()) if DEBUG;

  my $starttime = Time::Piece->strptime(get_value("Start Time", $item->description()), "%d/%m/%Y %H:%M");

  if($today->ymd eq $starttime->ymd) {            # If Safety Conversation starts today
    my $message = $messagetemplate;
    my $endtime = Time::Piece->strptime(get_value("End Time", $item->description()), "%d/%m/%Y %H:%M");
    my $participant = get_value("Participant", $item->description());
    my $area = get_value("Area", $item->description());
    my $emailaddress = get_value("E-Mail", $item->description());
    my $link = $item->link();

    $endtime = $endtime - 3600;                       # Sharepoint Event's dates are stored with the corresponding timezone (GMT or BST) already applied, there as the time isn't shown we simply remove an extra hour so that the end date will appear on the Sunday (instead of the Monday morning)

    $starttime = $starttime->strftime("%d/%m/%y");
    $endtime = $endtime->strftime("%d/%m/%y %H:%M");

	$link =~ s/ /%20/g;

    $message =~ s/%starttime%/$starttime/g;           # Replaced template parameters with actuals from the RSS feed
    $message =~ s/%endtime%/$endtime/g;
    $message =~ s/%participant%/$participant/g;
    $message =~ s/%area%/$area/g;
    $message =~ s/%link%/$link/g;

#    $emailaddress = 'michael.vickers@example.com';            # For testing, force the email to the system administrator

    $emailaddress =~ s/example.com/example.org/g;          # Force new domain name on email addresses

    my $email = Email::MIME->create_html(
      header => [
        'Reply-To'  => 'wss-no-reply@example.com',
        'To'        => $emailaddress,
        'From'      => '"Northern Mills" <IJMSharePoint@example.com>',
        'Subject'   => 'Safety Conversation Due',
      ],
      body => $message,
    );

    try {
      sendmail($email, { transport => $transport });
      say "Mail sent to $emailaddress";
      $emails += 1;
    } catch {
      warn "Email sending failed: $_";
    };

   # $email->header_set("To");                                                      # For testing/monitoring send the email to the administrator, ie like a BCC
   # $email->header_set("Cc", 'michael.vickers@example.co.uk');
   # try {
     # sendmail($email, { transport => $transport });
   # } catch {
     # warn "Email sending failed: $_";
   # };
  }

  $items += 1;
};

if(($today->fullday eq "Monday" && $emails == 0)) {       # There should always be some emails to send on a Monday
  say "No emails sent on a Monday!";

  my $email = Email::Simple->create(
    header => [
      'Reply-To'  => 'wss-no-reply@example.com',
      'To'        => 'michael.vickers@example.co.uk',
      'From'      => '"Northern Mills" <IJMSharePoint@example.com>',
      'Subject'   => 'Safety Conversation Reminder Failure',
    ],
    body => "Monday and expected emails to send were not encountered",
  );

  try {
    sendmail($email, { transport => $transport });
  } catch {
    warn "Email sending failed: $_";
  };
}

say "$items processed";
say "$emails sent";

$today = Time::Piece->new;
say $today->datetime . ": Finished";

exit 0;






### Subroutines ##################################

sub get_value {
  # Retrives a parameter from an RSS description field
  #   $_[0] = parameter name
  #   $_[1] = RSS description field
  #   Returns = parameter value or empty string if parameter does not exist in the description field

  if(index($_[1], $_[0]) == -1) {
    return "";
  }

  my $htmltag = "<b>" . $_[0].  ":</b> ";

  my $pos = index($_[1], $htmltag) + length($htmltag);
  my $len = index($_[1],  "</div>", $pos) - $pos;

  return substr($_[1], $pos, $len);
}
