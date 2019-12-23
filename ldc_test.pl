#!/usr/bin/perl
use strictures 2;
use 5.28.0;

use lib 'lib/';
use Device::LDC1101EVM;

$| = 1;
# FIXME: udev magic to give this a static name.
my $ldcthingy = Device::LDC1101EVM->new();
$ldcthingy->connect(
    device => '/dev/ttyACM0'
    );

$ldcthingy->stop_stream;

printf "Family: 0x%x\n", $ldcthingy->chip_id();

my $rid = $ldcthingy->rid();
printf "device in family: 0x%x\n", $rid >> 3;
printf "revision: 0x%x\n", $rid & 0b111;

my $ls_lsb = $ldcthingy->lhr_rcount_msb();
say "Read: $ls_lsb";
## write to some register
$ldcthingy->lhr_rcount_msb($ls_lsb+1);

my $new_ls_lsb = $ldcthingy->lhr_rcount_msb();
say "Read: $new_ls_lsb";

## test read only value:
$ldcthingy->chip_id(3);
printf "Family: 0x%x\n", $ldcthingy->chip_id();

## Start stream, read a chunk, stop:
my $resp = $ldcthingy->start_stream('RP+L');
$ldcthingy->stop_stream();
