#!/usr/bin/perl -w
use strict;
use POSIX;

# SCRIPT <file1.txt> <file2.txt> ... <filen.txt>
my $control_string = "%16d,%8d,%8d,%8d,%9d,%9d,%8d,%8d,%8d,%9d,%9d,%9d,%9d,%8d,%9d,%8d,%10d,%9d,%10d,%9d,%10d,%10d,%9ld";
my @control_array = split(',',$control_string);

my $numArgs = @ARGV + 1;
my @argument_files = @ARGV;
my @ALL_files;


foreach my $files (@argument_files) 
	{
		open(INPUT,$files) || die("Can't open input file $files");
		push @ALL_files, [ <INPUT> ];
		close INPUT;
	}

while ( 1 )
{
	my %values = ();
	## print  $ALL_files[0] . "\t" . $ALL_files[1] ."\t" . $ALL_files[2] . "\n";
	for my $i ( 0 .. $#ALL_files)
	{
		my @file_line=();
		my $file_line_ref;
		$file_line_ref = $ALL_files[$i];
		@file_line = @$file_line_ref;

		my $line = shift @file_line;
		if (!defined $line)
			{ exit; }
	
		if ($line !~ /^\s+\d+\s+\d+\s+\d+/)
			{
			print $line;
			$ALL_files[$i] = \@file_line;
			#print  $ALL_files[0] . "\t" . $ALL_files[1] ."\t" . $ALL_files[2] . "\n";
			for my $ii ( $i+1 .. $#ALL_files) {
			    my @file_line=();
			    $file_line_ref = $ALL_files[$ii];
			    #print $ii . "\t" . $file_line_ref . "\n";
			    @file_line = @$file_line_ref;
			    #print $ii . "\t" . \@file_line . "\n";
			    shift @file_line;
			    ##print $ii . "\t" . \@file_line . "\n";
			    $ALL_files[$ii] = \@file_line;
			    ##print  $ii . "\t" . $ALL_files[0] . "\t" . $ALL_files[1] ."\t" . $ALL_files[2] . "\n";
			}
			last;
			}

		$line =~ s/^\s+//;
		my @line_in_array = split('\s+', $line);

			for my $j (0 .. $#line_in_array)
			{	
					
				push @{ $values{$j} }, $line_in_array[$j];
				##print $i . "\t" . $line_in_array[$j] . "\n";

			}
	
		$ALL_files[$i] = \@file_line;
	}

	my @cntl_array = @control_array;
	for my $column_values  ( sort { $a <=> $b } (keys %values) ) 
	{
	my $avg;
 	if ( $column_values<2  ) {
	    $avg = ${ $values{$column_values} }[0];
	} else {
	    $avg = average(@{ $values{$column_values} });
	    $avg = int($avg + .5 * ($avg <=> 0));
	}
 	my $control_value = shift @cntl_array;

	my $average_value = sprintf $control_value, $avg;
	#print $average_value;
	printf "%9d", $average_value;
	}
print "\n" if scalar keys %values;
%values = ();
}

sub average
	{
		my @pole = @_;
		my $pocet = $#pole + 1;
		my $total = 0;
		
		foreach (@pole)
		{ 
		    $total += $_;
		    ##print $_ . "\n";
	       	}
		return $total / $pocet;	

	}
