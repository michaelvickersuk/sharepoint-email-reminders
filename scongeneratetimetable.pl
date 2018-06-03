#!/usr/bin/perl -w

# Michael Vickers
# 02/12/2016
# Outputs a timetable of Safety Conversation events in the format needed for import into SharePoint
# perl /etc/scripts/scongeneratetimetable.pl 2>&1 | splain
# perl /etc/scripts/scongeneratetimetable.pl > /etc/scripts/out.txt

use strict;
use warnings;
use 5.010;
#use diagnoistics;

use Carp::Assert;
use Carp::Assert::More;
use Time::Piece;

use constant EMAILDOMAIN => '@example.co.uk';

my $weekstart = Time::Piece->strptime('2017-04-03', '%Y-%m-%d');											# First day of the safety calendar year, typically April-to-March, usually first Monday of April
my @weeks = (1..52);
my @participantnames = ('Thiel, Keegan', 'Vandervort, Noemy', 'Kiehn, Karley');
my @participantemails = ('keegan.thiel' . EMAILDOMAIN, 'noemy.vandervort' . EMAILDOMAIN, 'karley.kiehn' . EMAILDOMAIN);
my $currentparticipant = 0;
my @highriskareas = ('Skinningrove: 1014c', 'Skinningrove: Mill Arch', 'Skinningrove: AB Bay', 'Skinningrove: Boiler Shop', 'Skinningrove: Apprentices', 'Skinningrove: Management of work');
my @mediumriskareas = ('Skinningrove: 36\'\' Mill', 'Skinningrove: Saw Sharpener / Side Press', 'Skinningrove: CD Bay', 'Skinningrove: Fitting Shop', 'Skinningrove: RSM Build Up', 'Skinningrove: Danieli Mill', 'Skinningrove: Scrap Burning Area / AVD Workshop', 'Skinningrove: Diesel Shed', 'Skinningrove: Transport', 'Skinningrove: No5 / TCI OHC Gantrys', 'Skinningrove: Roll Lathe Shop', 'Skinningrove: Bandsaw, CR Line, Inspection Area', 'Skinningrove: Guide Shop');
            #Note 36" mill above is double single quotes instead of one double quote, this is for compatibility with the datasheet view in SharePoint. Once the data has been imported (copy and pasted) it will require manually updating to a single double quote (input field option list also needs to be amended to allow the input of double single quotes in the first place!)

assert_is($#participantnames, $#participantemails) if DEBUG;    											# Must have the same number of participant names and email addresses
assert_is($#participantnames % 2, 0) if DEBUG;                  											# Must have an odd number of participants to prevent the same person having the same area every week

if (DEBUG) {																								# Must have corresponding participantnames and participantemails
	foreach my $i (0 .. $#participantemails) {
		my ($emaillocalpart) = split(/@/, $participantemails[$i]);
		my @emailname = split(/\./, $emaillocalpart);

		my ($lastname, $firstname) = split(/, | /, lc($participantnames[$i]));
		$firstname = $firstname || '';																			# Some user names don't contain a first name
		$lastname =~ tr/'//d;																					# Remove apostrophes from user name's surname

		assert_in($firstname, \@emailname) if DEBUG;
		assert_in($lastname, \@emailname) if DEBUG;
	}
}

# say "start\tend\tarea\tperson\temail\tallday";         # For testing puposes when importing into Excel to check totals per area or person

foreach my $week (@weeks) {
    my $weekend = $weekstart + (86400 * 6);        # 86400 seconds in a day

    foreach my $highriskarea (@highriskareas) {
        say $weekstart->strftime('%d/%m/%Y 00:00:00') . "\t" . $weekend->strftime('%d/%m/%Y 23:59:59') . "\t" . $highriskarea . "\t" . getnextparticipant() . "\t1";
    };

    foreach my $mediumriskarea (@mediumriskareas) {
        say $weekstart->strftime('%d/%m/%Y 00:00:00') . "\t" . $weekend->strftime('%d/%m/%Y 23:59:59') . "\t" . $mediumriskarea . "\t" . getnextparticipant() . "\t1";
    };

    if ($week % 4 == 1) {
        say $weekstart->strftime('%d/%m/%Y 00:00:00') . "\t" . $weekend->strftime('%d/%m/%Y 23:59:59') . "\tSkinningrove: Trailer Park / VMI / Ponderosa\t" . getnextparticipant() . "\t1";
    }

    if ($week % 4 == 2) {
        say $weekstart->strftime('%d/%m/%Y 00:00:00') . "\t" . $weekend->strftime('%d/%m/%Y 23:59:59') . "\tSkinningrove: Stores\t" . getnextparticipant() . "\t1";
    }

    if ($week % 8 == 3) {
        say $weekstart->strftime('%d/%m/%Y 00:00:00') . "\t" . $weekend->strftime('%d/%m/%Y 23:59:59') . "\tSkinningrove: Bloom Bay / Bloom Furnace\t" . getnextparticipant() . "\t1";
    }

    if ($week % 8 == 7) {
        say $weekstart->strftime('%d/%m/%Y 00:00:00') . "\t" . $weekend->strftime('%d/%m/%Y 23:59:59') . "\tSkinningrove: Intermediate Furnace\t" . getnextparticipant() . "\t1";
    }

    if ($week % 12 == 4) {
        say $weekstart->strftime('%d/%m/%Y 00:00:00') . "\t" . $weekend->strftime('%d/%m/%Y 23:59:59') . "\tSkinningrove: Billet Shed\t" . getnextparticipant() . "\t1";
    }

    if ($week % 12 == 8) {
        say $weekstart->strftime('%d/%m/%Y 00:00:00') . "\t" . $weekend->strftime('%d/%m/%Y 23:59:59') . "\tSkinningrove: Roll Storage Area\t" . getnextparticipant() . "\t1";
    }

    if ($week % 12 == 0) {
        say $weekstart->strftime('%d/%m/%Y 00:00:00') . "\t" . $weekend->strftime('%d/%m/%Y 23:59:59') . "\tSkinningrove: Weighbridge / Security\t" . getnextparticipant() . "\t1";
    }

    foreach my $highriskarea (@highriskareas) {
        say $weekstart->strftime('%d/%m/%Y 00:00:00') . "\t" . $weekend->strftime('%d/%m/%Y 23:59:59') . "\t" . $highriskarea . "\t" . getnextparticipant() . "\t1";
    };

    $weekstart += 604800;       # Add one week
};

exit 0;






### Subroutines ##################################

sub getnextparticipant {
  # Returns the next participant from the participant arrays

  if ($currentparticipant > $#participantemails) {
    $currentparticipant = 0;
  }

  return $participantnames[$currentparticipant] . "\t" . $participantemails[$currentparticipant++];

}
