#!/usr/bin/perl
use strictures 2;
use Time::HiRes 'sleep';
## Setup:
# Open serial to gcode output:
my $3dprinter;  # = something involving dev/ttyACM0 probably
# Initial GCODE gubbins?
setupPrinter($3dprinter);

#  Open serial to sensor
my $sensor; # = maybe dev/ttyUSB0 ?


# How big an area
my $min_x = 0;
my $min_y = 0;
my $max_x = 100;
my $max_y = 100;


# Divisions - start at 1, climb to ??
my $current_divisions = 1;
my $max_divisions;

my $max_dimension = $max_x - $min_x;
$max_dimension = $max_y - $min_y
    if ($max_y - $min_y > $max_dimension);

# Stop at 0.1 mm per step
$max_divisions = 10 * $max_dimension;

# Results!
my @output = ();

my %seen_loc;

while($current_divisions < $max_divisions) {
    for(my $x_loc = $min_x; $x_loc < $max_x; $x_loc += ($max_x-$min_x)/$current_divisions) {
        for(my $y_loc = 0; $y_loc < $max_y; $y_loc += ($max_y-$min_y)/$current_divisions) {
	    next if ($seen_loc{"$x_loc,$y_loc"}++);
	    moveHead($3dprinter, $x_loc, $y_loc);
	    
            my ($lval, $rpval) = readSensor($sensor);
            push @output, [ $x_loc, $y_loc, $lval, $rpval] ;
        }
    }

    $current_divisions *= 2;
}

sub moveHead($3dprinter, $x_loc, $y_loc) {
    $3dprinter->{fh}->say("G0X$x_locY$y_loc\n");
}

sub sensorWriteReg($sensor, $index, $val) {
    # See SNOU137 section 3.15 for offical definition of the protocol,
    # but
    # https://github.com/efti-nile/indosense-client/blob/master/indosense-client.py
    # gives a far better view of it.
    $sensor->{fh}->printf("%02x%02x%02x\cM\cJ", 0x02, $index, $val);
    local $/ = \8;
    # We need to read 8 bytes, because otherwise we will fall out of sync.  However,
    # these are underdocumented, and we don't really care, so we don't actually
    # do anything with them.
    my $in = <$sensor->{fh}>;
}
