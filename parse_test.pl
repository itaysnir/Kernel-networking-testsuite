#!/usr/bin/perl -w

use warnings;
use strict;
use File::stat;
use File::Basename;
use File::Grep qw (fgrep);
use Cwd 'abs_path';
use Switch;

my $TEST_SOURCE="/homes/itaysnir/Kernel-networking-testsuite";
my $OUT_DIR="/homes/itaysnir/Kernel-networking-testsuite/plots";

my %sort = (
	'4.8.0-unsafe' => 50,
	'4.7.0-unsafe' => 1,
	'4.7.0-defer' => 8,
	'4.7.0-deff' => 8,
	'4.7.0-strict' => 0,
	'4.7.0-damn-unsafe' => 2,
	'4.7.0-damnn-hpne-unsafe' => 3,
	'4.7.0-damn-strict' => 7,
	'4.7.0-damn-ne-strict' => 5,
	'4.7.0-damnn-hp-strict' => 6,
	'4.7.0-damn-ne-unsafe' => 4,
	'4.7.0-damnn-hpne-strict' => 8,
	'4.7.0-copy-plus-strict' => 3,
	'4.7.0-copy-plus-hp-strict' => 4,
	'4.7.0-damn-strict_512' => 60,
	'4.7.0-damn-strict_256' => 50,
	'4.7.0-damn-strict_128' => 40,
	'4.7.0-damn-strict_64' => 30,
	'4.7.0-damn-strict_32' => 20,
	'4.7.0-damn-strict_16' => 10,
	'4.7.0-damn-strict_4' => 0,
	'4.13.0-unsafe' => 3,
	'4.13.0PCOP-unsafe' => 2,
	'4.14.0-PCOP-defer' => 2,
	'4.13.0PCOP-defer' => 3,
	'4.14.0-PCOP-PF-unsafe' => 3,
	'4.14.0-PCOP-PF-defer' => 4,
	'4.14.0-damn-ne-unsafe' => 1,
	'4.14.0-PCOP-unsafe' => 2,
	'4.14.0-damn-ne_v1-defer' => 1,
	'4.14.0-defer' => 2,
	'4.14.0-damn-ne-unsafe_run1' => 1,
	'4.14.0-damn-ne-unsafe_run2' => 2,
);

#4.7.0-copy-plus-strict/
#4.7.0-damn-strict/
#4.7.0-deff/
#4.7.0-strict/
#4.7.0-unsafe/

sub lazy_dir {
### Lazy way of geting latest res dir

	my $dir = dirname(abs_path($0))."/Results/";
	my @files = glob($dir.'*');
	$dir = "$files[$#files -1]\n";
	chomp $dir;

	$dir = $ARGV[0] if (defined($ARGV[0]));
	die "dir <$dir> doesnt exist" unless (-d $dir);
	return $dir;
}

sub get_resfile_name {
	my $test_dir = shift;
	my $name = "$test_dir/results.out";
	my $str = localtime;
	qx(rm "$name"* ) if (-e $name);
	return $name;
}

sub avarage {
	my $arr = shift;

	my $total = 0;

	for my $i (@{$arr}) {
		$total += $i if ($i =~ /^[0-9._,]+$/);
		printf "$i : not numeric\n" unless ($i =~ /^[0-9,._]+$/ or $i =~ "N/A");
	}
	return ($total / ($#{$arr} + 1));
}

sub stdv {
	my $arr = shift;
	my $avg = shift;

	my $sigma = 0;

	for my $i (@{$arr}) {
		$sigma += ($i -$avg)**2 if ($i =~ /^[0-9._,]+$/);
	}
	return  sqrt($sigma / ($#{$arr} + 1));
}
########################################################
# PARSE subs
#######################################################
#L3MISS | L2MISS | L3HIT | L2HIT | L3MPI | L2MPI |  L3OCC |   LMB  |   RMB  |
#SKT    0     0.11   0.26   0.43    1.20     968 M   1090 M    0.11    0.26    0.06    0.07    36960    82653    20523     49
sub l2num {
	switch (shift) {
		case 'M' {return 1_000_000}
		case 'K' {return 1_000}
		else {die "$_ impossible switch...\n"}
	}
}

sub fill_pcm_hash {
	my $prfx = shift;
	my $hash = shift;
	my $line = shift;

	my @line = split(/\s+/, $line);

	my $ipc = $line[4];
	$$hash{"${prfx}_ipc"} = [] unless (exists $$hash{"${prfx}_ipc"});
	push (@{$$hash{"${prfx}_ipc"}}, $ipc);

	my $l3miss = $line[7] * l2num($line[8]);
	$$hash{"${prfx}_l3miss"} = [] unless (exists $$hash{"${prfx}_l3miss"});
	push (@{$$hash{"${prfx}_l3miss"}}, $l3miss);

	my $l2miss = $line[9] * l2num($line[10]);
	$$hash{"${prfx}_l2miss"} = [] unless (exists $$hash{"${prfx}_l2miss"});
	push (@{$$hash{"${prfx}_l2miss"}}, $l2miss);

	my $l3hit = $line[11];
	$$hash{"${prfx}_l3hit"} = [] unless (exists $$hash{"${prfx}_l3hit"});
	push (@{$$hash{"${prfx}_l3hit"}}, $l3hit);

	my $l2hit = $line[12];
	$$hash{"${prfx}_l2hit"} = [] unless (exists $$hash{"${prfx}_l2hit"});
	push (@{$$hash{"${prfx}_l2hit"}}, $l2hit);

	my $l3mpi = $line[13];
	$$hash{"${prfx}_l3mpi"} = [] unless (exists $$hash{"${prfx}_l3mpi"});
	push (@{$$hash{"${prfx}_l3mpi"}}, $l3mpi);

	my $l2mpi = $line[14];
	$$hash{"${prfx}_l2mpi"} = [] unless (exists $$hash{"${prfx}_l2mpi"});
	push (@{$$hash{"${prfx}_l2mpi"}}, $l2mpi);

	my $l3occ = $line[15];
	$$hash{"${prfx}_l3occ"} = [] unless (exists $$hash{"${prfx}_l3occ"});
	push (@{$$hash{"${prfx}_l3occ"}}, $l3occ);

}

sub parse_pcm_line {
	my $hash = shift;
	my $line = shift;

	#SKT    0     0.11   0.26   0.43    1.20     968 M   1090 M    0.11    0.26    0.06    0.07    36960    82653    20523     49
	if ($line =~ /SKT\s+0\s+[\d\.]+\s+[\d\.]+\s+[\d\.]+\s+[\d\.]+\s+/) {
		fill_pcm_hash 'SKT0', $hash, $line;
	}

	#SKT    0     0.11   0.26   0.43    1.20     968 M   1090 M    0.11    0.26    0.06    0.07    36960    82653    20523     49
	if ($line =~ /SKT\s+1\s+[\d\.]+\s+[\d\.]+\s+[\d\.]+\s+[\d\.]+\s+/) {
		fill_pcm_hash 'SKT1', $hash, $line;
	}

	#TOTAL  *     0.23   0.41   0.57    1.20    1704 M   2122 M    0.20    0.30    0.03    0.03     N/A     N/A     N/A      N/A
	if ($line =~ /TOTAL\s+\*\s+[\d\.]+\s+[\d\.]+\s+[\d\.]+\s+[\d\.]+\s+/) {
		fill_pcm_hash 'TOTAL', $hash, $line;
	}
	#Instructions retired:   65 G ; Active cycles:  160 G ; Time (TSC):   10 Gticks ; C0 (active,non-halted) core residency: 47.79 %
#if ($line =~ /Instructions retired:/) {
#
#}
}

sub parse_line {
	my $hash = shift;
	my $line = shift;

	## memc test
	if ($line =~ /^([\d\.]+)\s+Units/) {
		$$hash{iops} = [] unless (exists $$hash{iops});
		push (@{$$hash{iops}}, $1);
		return;
	}

	## proc/stat lines cpu: num
	if ($line =~ /^(\w*)\s*:\s*([\d\.]+)/) {
		printf "Got proc stat line";
		$$hash{$1} = [] unless (exists $$hash{$1});
		push (@{$$hash{$1}}, $2);
		return;
	}

	## perf line 3444 cycles
	if ($line =~ /^\s*(\d+)\s+([\w-]+)/) {
		printf "Got perf cycles line";
		$$hash{$2} = [] unless (exists $$hash{$2});
		push (@{$$hash{$2}}, $1);
		return;
	}

	## pcm-mem.x Throughput(MB/s):

	if ($line =~ /(\w+)\s+Throughput\(MB\/s\):\s*([\d\.]+)/) {
		printf "Parsing throughput";
		$$hash{$1} = [] unless (exists $$hash{$1});
		push (@{$$hash{$1}}, $2);
		return;
	}
}

sub parse_kernel_result {
	my $kernel = shift;
	my $out = shift;

	my $in = "$kernel/result.txt";
	die "file $in doesnt exist\n" unless (-e $in);

	open(my $in_handle, $in);
	#print "$in\n";

	my %results = ();
	while (my $line = <$in_handle>) {
		chomp $line;
		parse_line \%results, $line;
	}
	close $in_handle;
	$in = "$kernel/test_raw.txt";
	if ( -e $in) {
		open(my $in_handle, $in);
		while (my $line = <$in_handle>) {
			chomp $line;
			parse_line \%results, $line;
		}
		close $in_handle;
	}

	$in = "$kernel/result_pcm.txt";
	if ( -e $in) {
		open(my $in_handle, $in);
		while (my $line = <$in_handle>) {
			chomp $line;
			parse_pcm_line \%results, $line;
		}
		close $in_handle;
	}

	printf "writing to: $out\n";
	open(my $out_handle, '>>', $out);
	for my $key (keys(%results)) {
		my $avg  = avarage($results{$key});
		my $stdv = stdv($results{$key}, $avg);
		$kernel  = basename($kernel);
		my $str  = "$kernel:$key:$avg:$stdv";
		print $out_handle "$str\n";
	}
	close $out_handle;
}

sub parse_test {
	#	Itay change!
	#
	#	my $test_dir = shift;
	#my @kernels  = glob($test_dir.'/*');

	#my $res_file = get_resfile_name $test_dir;

	#for my $kernel (@kernels) {
	#		printf "Kernel: $kernel\n";
	#		next unless (-d $kernel);
	#		parse_kernel_result($kernel, $res_file);
	#}

	my $test_dir = shift;
	my $res_file = get_resfile_name $test_dir;

	if (-d $test_dir) {
		parse_kernel_result($test_dir, $res_file);
	}

}
#########################################################################################################
# PLOT subs
#################################################################
my @plots = qw(irq_total cpu_total Total_tx_packets Total_tx_bytes Total_rx_packets Total_rx_bytes Memory iops instructions cycles
		SKT0_ipc SKT0_l3miss SKT0_l2miss SKT0_l3hit SKT0_l2hit SKT0_l3mpi SKT0_l2mpi SKT0_l3occ
		SKT1_ipc SKT1_l3miss SKT1_l2miss SKT1_l3hit SKT1_l2hit SKT1_l3mpi SKT1_l2mpi SKT1_l3occ
		TOTAL_ipc TOTAL_l3miss TOTAL_l2miss TOTAL_l3hit TOTAL_l2hit TOTAL_l3mpi TOTAL_l2mpi
		cache-misses cache-references LLC-store LLC-store-misses LLC-load LLC-load-misses

		);

my %extra_plots = (
	'Bandwidth'	=> \&plot_bw,
	'L2miss_Byte'	=> \&plot_miss2_byte,
	'L3miss_Byte'	=> \&plot_miss3_byte,
	'Cycles_Byte'	=> \&plot_cyc_byte,
	'Ins_Byte'	=> \&plot_ins_byte,
	'Ins_Packet'	=> \&plot_ins_packet,
	'Cycles_Packet' => \&plot_cyc_packet,
	'Ins_cycle'	=> \&plot_ipc,
	'TX_Bytes_Packets' => \&plot_tx_byte_p_pack,
	'RX_Bytes_Packets' => \&plot_rx_byte_p_pack,
);

sub plot_values {
	my $values = shift;
	my $fh = shift;
	my $hash = shift;
	#printf "%s\n @{$values}\n", dirname(abs_path($0));

	my $idx = 0;
	my @plot = ();

	foreach my $val (@{$values}) {
		my @line = split(/:/, $val);
		$idx = $sort{$line[0]};

		die "$line[0] not defined in the %sort hash" unless defined $idx;

		die "$val wheres my arror bitch?" unless defined $line[3];
		$plot[$idx]  = "$idx $line[0] $line[2] $line[3]";
		${$hash}{$line[0]} = $line[2]; #store the result for compound graphs
	}
	foreach my $val (@plot) {
		$val = 0 unless defined $val;
		print $fh "$val";
	}
}

sub prepare_gnuplot {
		my ($file_path, $test_name, $plot, $xrange, $err) = @_;
		$err = "_err" if defined $err;
		$err = "_" unless defined $err;
		qx(rm -f $file_path/*.plot; cp $file_path/single${err}bar._plot $file_path/${test_name}_$plot.plot);
		qx(sed -i s/FILE_NAME/${test_name}_$plot/g $file_path/${test_name}_$plot.plot);
		qx(sed -i s/VAL_NAME/$plot/g $file_path/${test_name}_$plot.plot);
		qx(sed -i s/XRANGE/$xrange/g $file_path/${test_name}_$plot.plot);

		open( my $fh, '>', "$file_path/data.dat");
		return $fh;
}

sub plot_tx_byte_p_pack {
	my $hash = shift;
	my $fh = shift;

	my $idx = 1;
	foreach my $kernel (sort {$sort{$a} <=> $sort{$b}} keys(%{$$hash{Total_tx_bytes}})) {
		my $bw = 0;
		unless ($$hash{Total_tx_packets}{$kernel} == 0) {
			$bw = $$hash{Total_tx_bytes}{$kernel} / $$hash{Total_tx_packets}{$kernel};
		}
		print $fh "$idx $kernel $bw\n";
		$idx++;
	}
}

sub plot_rx_byte_p_pack {
	my $hash = shift;
	my $fh = shift;

	my $idx = 1;
	foreach my $kernel (sort {$sort{$a} <=> $sort{$b}} keys(%{$$hash{Total_rx_bytes}})) {
		my $bw = 0;
		unless ($$hash{Total_rx_packets}{$kernel} == 0) {
			$bw = $$hash{Total_rx_bytes}{$kernel} / $$hash{Total_rx_packets}{$kernel};
		}
		print $fh "$idx $kernel $bw\n";
		$idx++;
	}
}

sub plot_bw {
	my $hash = shift;
	my $fh = shift;

	my $idx = 1;
	foreach my $kernel (sort {$sort{$a} <=> $sort{$b}} keys(%{$$hash{Total_tx_bytes}})) {
		my $bw = $$hash{Total_tx_bytes}{$kernel} + $$hash{Total_rx_bytes}{$kernel};
		$bw *= 8;
		$bw /= (1000 * 1000 * 1000);
		print $fh "$idx $kernel $bw\n";
		$idx++;
	}
}

sub plot_cyc_packet {
	my $hash = shift;
	my $fh = shift;

	my $idx = 1;
	foreach my $kernel (sort {$sort{$a} <=> $sort{$b}} keys(%{$$hash{Total_tx_packets}})) {
		my $bw = $$hash{Total_tx_packets}{$kernel} + $$hash{Total_rx_packets}{$kernel};
		my $val = 0;
		$val = $$hash{cycles}{$kernel}/$bw if ($bw);
		print $fh "$idx $kernel $val\n";
		$idx++;
	}
}

sub plot_ins_packet {
	my $hash = shift;
	my $fh = shift;

	my $idx = 1;
	foreach my $kernel (sort {$sort{$a} <=> $sort{$b}} keys(%{$$hash{Total_tx_packets}})) {
		my $bw = $$hash{Total_tx_packets}{$kernel} + $$hash{Total_rx_packets}{$kernel};
		my $val = 0;
		$val = $$hash{instructions}{$kernel}/$bw if ($bw);
		print $fh "$idx $kernel $val\n";
		$idx++;
	}
}

sub plot_miss2_byte {
	my $hash = shift;
	my $fh = shift;

	my $idx = 1;
	foreach my $kernel (sort {$sort{$a} <=> $sort{$b}} keys(%{$$hash{Total_tx_bytes}})) {
		my $bw = $$hash{Total_tx_bytes}{$kernel} + $$hash{Total_rx_bytes}{$kernel};
		my $val = 0;
		$val = $$hash{TOTAL_l2miss}{$kernel}/$bw if ($bw);
		print $fh "$idx $kernel $val\n";
		$idx++;
	}
}

sub plot_miss3_byte {
	my $hash = shift;
	my $fh = shift;

	my $idx = 1;
	foreach my $kernel (sort {$sort{$a} <=> $sort{$b}} keys(%{$$hash{Total_tx_bytes}})) {
		my $bw = $$hash{Total_tx_bytes}{$kernel} + $$hash{Total_rx_bytes}{$kernel};
		my $val = 0;
		$val = $$hash{TOTAL_l3miss}{$kernel}/$bw if ($bw);
		print $fh "$idx $kernel $val\n";
		$idx++;
	}
}

sub plot_cyc_byte {
	my $hash = shift;
	my $fh = shift;

	my $idx = 1;
	foreach my $kernel (sort {$sort{$a} <=> $sort{$b}} keys(%{$$hash{Total_tx_bytes}})) {
		my $bw = $$hash{Total_tx_bytes}{$kernel} + $$hash{Total_rx_bytes}{$kernel};
		my $val = 0;
		$val = $$hash{cycles}{$kernel}/$bw if ($bw);
		print $fh "$idx $kernel $val\n";
		$idx++;
	}
}

sub plot_ins_byte {
	my $hash = shift;
	my $fh = shift;

	my $idx = 1;
	foreach my $kernel (sort {$sort{$a} <=> $sort{$b}} keys(%{$$hash{Total_tx_bytes}})) {
		my $bw = $$hash{Total_tx_bytes}{$kernel} + $$hash{Total_rx_bytes}{$kernel};
		my $val = 0;
		$val = $$hash{instructions}{$kernel}/$bw if ($bw);
		print $fh "$idx $kernel $val\n";
		$idx++;
	}
}

sub plot_ipc {
	my $hash = shift;
	my $fh = shift;

	my $idx = 1;
	foreach my $kernel (sort {$sort{$a} <=> $sort{$b}} keys(%{$$hash{instructions}})) {
		my $ins = $$hash{instructions}{$kernel};
		my $val = $ins/$$hash{cycles}{$kernel};
		print $fh "$idx $kernel $val\n";
		$idx++;
	}
}

### TODO: Break qx to script.sh
sub plot_results {
	my $test_dir = shift;
	my $name = "$test_dir/results.out";
	my $test_name = basename(dirname($name));
	#	my $file_path = dirname(abs_path($0))."/Gnuplot";
	
	my $file_path = "$TEST_SOURCE/Gnuplot";
	printf "Filepath: $file_path\n";

	qx(mkdir -p $OUT_DIR/$test_name; rm -f $file_path/*.eps);

	## per test: hash{plot}{kernel} = value
	my $xrange = 0;
	my %hash = ();
	## can collect from file all the keys automagicaly, but we limit it intentionally
	foreach my $plot (@plots) {
		my @values = qx(grep -P \"$plot\\W\" $name);
		printf "skipping $plot\n@values" and next unless ($#values > 0);
		printf "Plotting: $plot\n";
		$hash{$plot} = {};
		## Create a custom gnuplot file
		$xrange = ($#values + 2) if ($xrange < ($#values + 2));
		my $fh = prepare_gnuplot $file_path, $test_name, $plot, $#values + 2, 'err';
		plot_values \@values, $fh, $hash{$plot};
		close $fh;

		#plot results
		qx(cd $file_path; gnuplot $file_path/${test_name}_$plot.plot; epstopdf ${test_name}_$plot.eps 2> /dev/null ; mv *.pdf $OUT_DIR/$test_name; rm -f *.eps; rm -f *.plot);
	}

	foreach my $plot (keys(%extra_plots)) {
		my $fh = prepare_gnuplot $file_path, $test_name, $plot, $xrange;
		$extra_plots{$plot}->(\%hash, $fh);
		close $fh;
		qx(cd $file_path; gnuplot $file_path/*.plot; epstopdf *.eps 2> /dev/null ; mv *.pdf $OUT_DIR/$test_name; rm -f *.eps; rm -f *.plot);
	}
	qx(cp $name $OUT_DIR/$test_name);
	printf("ls -l  $OUT_DIR/$test_name\n");
}
############################################ PCM RESULTS #######################################
#SKT    0     0.11   0.26   0.43    1.20     968 M   1090 M    0.11    0.26    0.06    0.07    36960    82653    20523     49
#SKT    1     0.35   0.50   0.71    1.20     736 M   1031 M    0.29    0.34    0.01    0.02    35616    62866     3899     45
# TOTAL  *     0.23   0.41   0.57    1.20    1704 M   2122 M    0.20    0.30    0.03    0.03     N/A     N/A     N/A      N/A
# Instructions retired:   65 G ; Active cycles:  160 G ; Time (TSC):   10 Gticks ; C0 (active,non-halted) core residency: 47.79 %
################################################################################################3


##########################
my $dir = lazy_dir();
my @tests = glob($dir.'/*');

printf "working on $dir\n";
for my $test (@tests) {
	parse_test $test;
	## When possible create pm file and sepparate parse from plot
	if (-d $test) {
		#		plot_results $test;
	}
}

