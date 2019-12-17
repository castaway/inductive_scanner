#!/usr/bin/perl
use strictures 2;
use feature 'signatures';
use Time::HiRes 'sleep';
use Device::SerialPort;
use autodie;
$|=1;
## Setup:
# Open serial to gcode output:
my $printer = { port => '/dev/ttyACM0' };  # = something involving dev/ttyACM0 probably

# Initial GCODE gubbins?
setupPrinter($printer);

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
	    print "$x_loc, $y_loc\n";
	    next if ($seen_loc{"$x_loc,$y_loc"}++);
	    moveHead($printer, $x_loc, $y_loc);
	    
            my ($lval, $rpval) = readSensor($sensor);
            push @output, [ $x_loc, $y_loc, $lval, $rpval] ;

        }
    }
	    die;

    $current_divisions *= 2;
}

sub setupPrinter($printer) {
    #    open(my $pfh, '+<', $printer->{port}) or die "Can't open ".$printer->{port};
    my $port = Device::SerialPort->new('/dev/ttyACM0');
    $port->databits(8);
    $port->baudrate(115200);
    $port->parity('none');
    $port->stopbits(1);
    $printer->{fh} = $port;

    #print $pfh "N0 M110 N0*25\n";
    $port->write("G21\n"); # units, mm
    $port->write("G90\n"); # positioning, absolute
    $port->write("G28XYZ\n"); # Home!
}

sub readSensor($sensor) {
}

sub moveHead($printer, $x_loc, $y_loc) {
    print "Moving to $x_loc, $y_loc\n";
    die "huge x: $x_loc" if $x_loc > 200;
    die "huge y: $y_loc" if $y_loc > 200;
    
    $printer->{fh}->write("G0X${x_loc}Y${y_loc} F6000\n");
    $printer->{fh}->write("M400\n");
    # All motors off (so as to not effect the reading).
    $printer->{fh}->write("M18\n");

    sleep 0.1;
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
    my $in = $sensor->{fh}->readline;
}
