package Device::LDC1101EVM;

=head1 NAME

Device::LDC110EM

=head1 DESCRIPTION

Read data from a texas instruments ldc110em dev board via usb.

=cut

use strictures 2;
use Device::SerialPort;
use 5.28.0;
use Sub::Name;

use Moo;

has 'port' => (is => 'rw');
has 'asleep' => (is => 'rw');

my $READ_REGISTER_CMD = 3;
my $WRITE_REGISTER_CMD = 2;


sub BUILD {
    my ($self) = @_;
    # Right, time for one of my most favourite things about perl, the
    # degree to which you can cheat / metaprogram.

    # future: consider importing the Register Map.xml that comes with
    # the evm software?  Downside, us export declaration.  Upside, can
    # generate methods for values that do not align perfectly with
    # registers.  current source: ldc1101 datasheet section 8.6
    my %reg_names = (
        rp_set => 1,
        tc1 => 2,
        tc2 => 3,
        dig_config => 4,
        alt_config => 5,
        rp_thresh_h_lsb => 6,
        rp_thresh_h_msb => 7,
        rp_thresh_l_lsb => 8,
        rp_thresh_l_msb => 9,
        intb_mode => 0xa,
        start_config => 0xb,
        d_conf => 0xc,
        l_thresh_hi_lsb => 0x16,
        l_thresh_hi_msb => 0x17,
        l_thresh_lo_lsb => 0x18,
        l_thresh_lo_msb => 0x19,
        status => 0x10,
        rp_data_lsb => 0x21,
        rp_data_msb => 0x22,
        l_data_lsb => 0x23,
        l_data_msb => 0x24,
        lhr_rcount_lsb => 0x30,
        lhr_rcount_msb => 0x31,
        lhr_offset_lsb => 0x32,
        lhr_offset_msb => 0x33,
        lhr_config => 0x34,
        lhr_data_lsb => 0x38,
        lhr_data_mid => 0x39,
        lhr_data_msb => 0x3a,
        lhr_status => 0x3b,
        rid => 0x3e,
        chip_id => 0x3f,
        );
    for my $key (keys %reg_names) {
        my $reg_num = $reg_names{$key};
        my $sub = sub {
            my ($self, $val) = @_;
            if(!$self->port) {
                die "Not connected to a port yet!";
            }
            if (@_ == 1) {
                return $self->read_reg($reg_num);
            } else {
                return $self->write_reg($reg_num, $val);
            }
        };
        subname $key, $sub;
        {
            no strict 'refs';
            *$key = $sub;
        }
    }
}

sub connect {
    my ($self, %port_args) = @_;

    my $port = Device::SerialPort->new($port_args{device}) or die "Can't open ${port_args{device}}";
    $port->baudrate($port_args{baudrate} || 115200);
    $port->databits($port_args{databits} || 8);
    $port->parity($port_args{parity} || 'none');
    $port->stopbits($port_args{stopbits} || 1);
    $port->handshake($port_args{handshake} || 'none');

    $port->write_settings() or die "Can't write port settings";

    $port->purge_all;

    $self->port($port);
}

sub read_reg {
    my ($self, $reg) = @_;
    $self->send_command($READ_REGISTER_CMD, $reg);
    $self->port->read_const_time(1000);
    my $in = $self->port->read(26);
    
    #say "Response length (before trim): ", length($in);
    
    my @in = map {ord} split //, $in;
    
    say "Response length: ", length($in);
    say "Response from read_reg: <<<$in>>>";
    for (0..$#in) {
        print "$_: $in[$_], ";
    }
    say('');

    # NB: Does not agree with documentation!
    return $in[2];
}

=head2 write_reg

Args: reg value (use the generated subs!), value to set.

Returns: the value it tried to write (even if it failed!?)

=cut

sub write_reg {
    my ($self, $reg, $val) = @_;
    $self->send_command($WRITE_REGISTER_CMD, $reg, $val);

    $self->port->read_const_time(1000);
    my $in = $self->port->read(255);
    
    say "Response length (before trim): ", length($in);
    
    my @in = map {ord} split //, $in;
    
    say "Response length: ", length($in);
    say "Response from write_reg: <<<$in>>>";
    for (0..$#in) {
        print "$_: $in[$_], ";
    }
    say('');

    # NB: Does not agree with documentation!
    return $in[0];

}

sub send_command {
    my ($self, @bytes) = @_;
    my $command_string = join '', map {sprintf "%02X", $_} @bytes;
    $command_string .= "\cM\cJ";

    my $written_len = $self->port->write($command_string);
    if ($written_len == 0) {
        die "Not written: $!";
    } elsif ($written_len != length($command_string)) {
        die "Write wrong len, got $written_len, expected ".length($command_string);
    }

    $self->port->read_const_time(1000);
    my $readback = $self->port->read(length($command_string));
    if ($readback ne $command_string) {
        die "echo-back of command failed, sent '$command_string' but got '$readback'";
    }
}

sub sleep {
  my ($self) = @_;

  # Note that the rest of the register is reserved-write-zero, so we
  # don't need to do fancy masking
  #my $start_config = $self->start_config;
  #$start_config &= ~ 0b11;
  #$start_config |= 0b01;
  $self->start_config(1);
  $self->asleep(1);
}

sub wake_up {
  my ($self) = @_;

  my $start_config = $self->start_config(0);

  $self->asleep(0);
}

# ldc1101 datasheet section 9.1.3
# if not HIGH_Q_SENSOR
# max16 = (1<<16) - 1
# Rp(RPmax, RPmin, RPDATA)
# fsensor = (clkin * resp_time) / (3 * l_data)
# lsensor = 1 / (csensor * (2*pi*fsensor)**2


1;
