
use strict;
use warnings;

## Setup:
# Open serial to gcode output:
my $3dprinter;  # = something involving dev/ttyACM0 probably
# Initial GCODE gubbins?
setupPrinter($3dprinter);

#  Open serial to sensor
my $sensor; # = maybe dev/ttyUSB0 ?

# Divisions - start at 1, climb to ??
my $current_division = 1;
my $max_division = 10;

# How big an area
my $max_x = 10;
my $max_y = 10;

# Results!
my @output = ();

while($current_division < $max_division) {
    for(my $x_loc = 0; $x_loc < $max_x; $x_loc += $current_division/$max_x) {
        for(my $y_loc = 0; $y_loc < $max_y; $y_loc += $current_division/$max_y) {
            moveSensor($3dprinter, $x_loc, $y_loc);
            my ($lval, $rsupval) = readSensor($sensor);
            push @output, [ $x_loc, $y_loc, $lval, $rsupval] ;
        }
    }
}
