#!/usr/bin/perl -w

package StatCollect;

use strict;
use autodie;
use Time::HiRes qw(time);
use Scalar::Util qw(looks_like_number);
use Term::ANSIColor qw(:constants colored);
require Exporter;

our @ISA=qw(Exporter);
our @EXPORT=qw(start_proc_cpu stop_proc_cpu start_ethtool stop_ethtool
		draw_cpu_util start_proc_interrupts stop_proc_interrupts
		start_ethtool_full stop_ethtool_full draw_mem get_ifs);

use constant USER_HZ => 100;
#################################### GLOBALS ######################################################
my $proc_start_time = 0;
my %proc_start_time = ();

my %proc_out = ();
my @proc_cpu_out = ();

my %eth_start_time = ();
my %eth_out = ();

#################################### STATICS ######################################################
sub sum_irq {
	my $out = shift;
	my $sum = 0;

	foreach (@{$out}) {
		next unless (/^\s*\d+:([\d\s]+)\w/);
		my @irqs = split /\s+/, $1;
		foreach my $irq (@irqs) {
			next unless ($irq =~ /\d+/);
			$sum += $irq;
		}
	}
	return $sum;
}

sub diff_proc_interrupts
{
	my $ref = shift;
	my $start = sum_irq $proc_out{'irq'};
	my $end = sum_irq $ref;
	return ($end - $start);
}

# proc stat based cpu util, proc/stat misses some ticks so only idle(idx 4) are valid
# int(time * USER_HZ) = expected total ticks ET.
# cpu util = ET - Ticks/ET;
sub diff_proc_cpu
{
	my $in_array = shift;
	my @out_array = ();

	my $i = 0;
	foreach my $line (@{$in_array}) {
		my @line = split(/\s+/, $line);
		my @orig = split(/\s+/, $proc_cpu_out[$i]);
		$i++;

		die "$line[0] != $orig[0]\n" unless ($line[0] eq $orig[0]);

		push(@out_array,  $line[5] + $line[4] - $orig[5] - $orig[4]);
	}
	return \@out_array;
}

sub diff_ethtool
{
	my $if = shift;
	my $time = shift;
	my $start_array_ref = $eth_out{$if};
	my $in_array = shift;

	my $i = 0;

	my %out_hash = ();

	foreach (@{$in_array}) {
		my @line = split(/:/, $_);
		my @orig = split(/:/, $$start_array_ref[$i]);
		$i++;

		die "$line[0] != $orig[0]\n" unless ($line[0] eq $orig[0]);
		$line[0] =~ s/^\s+//;
		$line[0] =~ s/\s+$//;
		$out_hash{$line[0]} =  int(($line[1] - $orig[1])/$time);
	}
	return \%out_hash;
}

##################################### EXPORTS #####################################################
#proc/stat based cpu util functions
sub start_proc_interrupts
{
	die "proc start is not 0" if (defined($proc_start_time{'irq'}) and ($proc_start_time{'irq'} != 0));
	$proc_start_time{'irq'} = time;

	open(my $fh, '<', "/proc/interrupts");
	my @out = grep {$_ =~ 'mlx5'} <$fh>;
	$proc_out{'irq'} = \@out;
	close $fh;
}

sub stop_proc_interrupts
{
	die "proc start is 0" if ($proc_start_time{'irq'} == 0);
	my $time = time - $proc_start_time{'irq'};
	$proc_start_time{'irq'} = 0;

	open(my $fh, '<', "/proc/interrupts");
	my @out = grep {$_ =~ 'mlx5'} <$fh>;
	close $fh;
	return (diff_proc_interrupts \@out)/$time;
}

sub start_proc_cpu
{
	die "proc start is not 0" unless ($proc_start_time == 0);
	$proc_start_time = time;

	open(my $fh, '<', "/proc/stat");
	@proc_cpu_out = grep {$_ =~ 'cpu'} <$fh>;
	close $fh;
}

sub max {
	my ($a, $b) = @_;
	return ($a > $b) ? $a : $b;
}

#returns a ref to and array of cpu util as %, idx 0 is total cpu util
sub stop_proc_cpu
{
	die "proc start is 0" if ($proc_start_time == 0);
	my $time = time - $proc_start_time;
	$proc_start_time = 0;

	open(my $fh, '<', "/proc/stat");
	my @proc = grep {$_ =~ 'cpu'} <$fh>;
	close $fh;
	my $idle_ref = diff_proc_cpu \@proc;

	my $ET = int(USER_HZ * $time);
	my $num_cpu = $#$idle_ref;
	my @cpu_util = ();

	$cpu_util[0] = max(0, 100 * ($ET * $num_cpu - $$idle_ref[0])/($ET * $num_cpu));

	for my $ticks (@{$idle_ref}[1..$#$idle_ref]) {
		push(@cpu_util, max(0, 100 * ($ET - $ticks)/$ET));
	}
	return \@cpu_util;
}

#collect bytes/packets for a specific interface
sub start_ethtool
{
	my $if = shift;
	die "usage start_ethtool <if_name>\n" unless (defined($if));
	die "eth start was called twice for $if" if (defined ($eth_start_time{$if}));
	$eth_start_time{$if} = time;

	my @eth_out = grep {$_ =~ '\s[tr]x_packets|\s[tr]x_bytes'} qx(ethtool -S $if);
	$eth_out{$if} = \@eth_out;
}

sub stop_ethtool
{
	my $if = shift;
	die "usage stop_ethtool <if_name>\n" unless (defined($if));
	die "eth stop was called before start for $if" unless (defined $eth_start_time{$if});

	my $time = time - $eth_start_time{$if};
	undef $eth_start_time{$if};

	my @eth_out = grep {$_ =~ '\s[tr]x_packets|\s[tr]x_bytes'} qx(ethtool -S $if);
	my $num_ref = diff_ethtool $if, $time, \@eth_out;

	undef $eth_out{$if};
	return $num_ref
}

sub start_ethtool_full
{
	my $if = shift;
	die "usage start_ethtool <if_name>\n" unless (defined($if));
	die "eth start was called twice for $if" if (defined ($eth_start_time{$if}));
	$eth_start_time{$if} = time;

	my @eth_out = qx(ethtool -S $if);
	$eth_out{$if} = \@eth_out;
}

sub stop_ethtool_full
{
	my $if = shift;
	die "usage stop_ethtool <if_name>\n" unless (defined($if));
	die "eth stop was called before start for $if" unless (defined $eth_start_time{$if});

	my $time = time - $eth_start_time{$if};
	undef $eth_start_time{$if};

	my @eth_out =  qx(ethtool -S $if);
	my $num_ref = diff_ethtool $if, $time, \@eth_out;

	undef $eth_out{$if};
	return $num_ref
}

# ASCII Draw cpu utilization based on stop_proc_cpu output
sub draw_cpu_util
{
	my $cpu_ref = shift;
	die "usage draw_cpu_util <cpu_util_ref(stop_proc_cpu)>" unless (defined $cpu_ref);

	foreach (1 .. $#$cpu_ref) {
		my $util = ($$cpu_ref[$_] >= 0 ) ? int($$cpu_ref[$_]) : 0;
		my $util_str;
		if ($util > 95) {
			$util_str = RED '|'x($util *0.5);
		} else {
			$util_str = BLUE '|'x($util *0.5);
		}
		printf "cpu%2d [%s%s%s]%3d\n", $_ -1, $util_str , RESET,' 'x(50 - $util), $util;
	}
}

sub line2num {
	my $line = shift;
	my @tmp = split /:/, $line;
	chomp $tmp[1];
	my $total = $tmp[1];
	$total =~ /(\d+)/g;
	return $1;
}

sub draw_mem {

	open(my $fh, '<', "/proc/meminfo");
	my @total = grep {$_ =~ /Mem[TF]/} <$fh>;

	my $total = line2num $total[0];
	my $free = line2num $total[1];
	my $len = int((100 * ($total -$free)/$total)/2);

	my $str =  GREEN '|'x$len;
	my $blank = ' 'x(50-$len);
	printf "Memory [%s%s%s] %3.2f/%3.2fGB\n", $str, RESET, $blank,
		, ($total-$free)/(1024  * 1024)	, $total/(1024  * 1024);

}

#returns list of configured(!) interfaces for supported drivers.
# current list: mlx5_core
sub get_ifs {
	my @list = ();
	my %supported_drivers = (mlx5_core => undef,);
	my @ifcfg = qx (ifconfig);

	foreach (@ifcfg) {
		chomp;
		next unless (/^(\w+)/);
		my $if = $1;
		my @drv = qx(ethtool -i $1);

		foreach (@drv) {
			next unless (/driver\s*:\s*(\w+)/);
			#printf "$if -> $1\n" if (exists($supported_drivers{$1}));
			push @list, $if if (exists($supported_drivers{$1}));
		}

	}
	return \@list;
}
###################################################################################################
1
