#!/usr/bin/perl

use strict;

use Math::BigFloat;
Math::BigFloat->accuracy(16);
my Math::BigFloat $bigNum= new Math::BigFloat '1.0';

use List::Util qw(min max);

my $version="V1.4";
my $line="";
my $skipStuff;

my $filenum=0;
my $totfiles=0;
my $printRecFileAnalysis=1;

my @row_iozone = ();
my $row2update;

my @ioTypes=();
my $numColumns;
my $numColumns1;

my @all_geomean = ();
my @recsize_geomean = ();
my @filesize_geomean = ();
my $min_recsize;
my $max_recsize;
my $min_filesize;
my $max_filesize;

my @all_geomean1 = ();
my @recsize_geomean1 = ();
my @filesize_geomean1 = ();
my $min_recsize1;
my $max_recsize1;
my $min_filesize1;
my $max_filesize1;

my @all_geomean_cmp = ();
my @recsize_geomean_cmp = ();
my @filesize_geomean_cmp = ();

my @rec_sizes = ();
my @file_sizes = ();
my $lines;

# INITIALIZE THE ROWS FOR EACH FILE PROCESSING
#
sub init_rows
    {
    @row_iozone = ();

    @all_geomean = ();
    @recsize_geomean = ();
    @filesize_geomean = ();

    @rec_sizes = ();
    @file_sizes = ();

    $lines = 0;
    $skipStuff=1;

    push @all_geomean, { tblName=>'ALL', numItems=>0, iwrite=>$bigNum, rewrite=>$bigNum,
	iread=>$bigNum, reread=>$bigNum, randrd=>$bigNum, randwr=>$bigNum, bkwdrd=>$bigNum,
	recrewr=>$bigNum, striderd=>$bigNum, fwrite=>$bigNum, frewrite=>$bigNum,
	fread=>$bigNum, freread=>$bigNum, allIOs=>$bigNum };
    }

sub help_msg
    {
    print "\n";
    print "usage: analysis-iozone.pl [ -a ] iozonefile.out\n";
    print "       analysis-iozone.pl [ -a ] iozonefile1.out iozonefile2.out\n\n";
    print "    -h     prints this message\n";
    print "    -a     only process and print data about ALL record sizes and filesizes\n\n";
    print "    Tool will calculate geometric mean of all iozone columns additionally breaking it\n";
    print "    down by all record sizes as well as by all filesizes.  If two files are specified,\n";
    print "    then their correspinding values will be compared.  Any regression greater than\n";
    print "    5% is flagged as well as any improvement greater than 5%\n\n";
    exit 0;
    }

# SEARCH FOR VALUE IN THE LIST
#
sub inlist
    {
    my $val=shift;
    my @theList=@_;
    my $idx;

    for ( $idx=0; $idx < ($#theList + 1); $idx++)
	{
	if ( $theList[ $idx ] == $val )
	    { return 0; }
	}
    return 1;
    }

# MULTIPLY ARG 2s ROW TO ARG 1s AND DIV BY 1K for MB RATE
#
sub  mult_row
    {
    my $rowMult2=$_[0];
    my $rowVal=$_[1];

    for my $iotype ( @ioTypes )
	{ $rowMult2->{$iotype} = ($rowMult2->{$iotype} * $rowVal->{$iotype}) /1024; }

    $rowMult2->{numItems} += 1;
    }

# FIND ROW # THAT MATCHES
#
sub find_row
    {
    my $type2find=shift;
    my $search4=shift;
    my @theTable=@_;

    my $idx;

    for ($idx=0; $idx <= $#theTable; $idx++)
	{
	if ( @theTable[ $idx ]->{$type2find} == $search4 )
	    { return $idx; }
	}
    print "ERROR - Search cant fail .. find_row\n";
    exit 1;
    }

# NROOT ALL ENTRIES IN THE TABLES, ALSO BUILD GEOMEAN FOR ALL COLUMNS BASED
# ON GEOMEAN OF EACH COLUMN.
#
sub nroot_row
    {
    my @theTable=@_;
    my $nroot;
    my $ref;

    for (my $idx=0; $idx <= $#theTable; $idx++)
	{
	$ref = @theTable[ $idx ];
	$nroot = $ref->{numItems};
	for my $iotype ( @ioTypes )
	    {
	    $ref->{$iotype} **= (1/$nroot);
	    $ref->{allIOs} *= $ref->{$iotype};
	    }
	$ref->{allIOs} **= (1/$numColumns);
	}
    }

# PRINT HEADER OF SUMMARY TABLE
#
sub print_header
    {
    my $whichTable=shift;
    my $tableHeader=shift;
    my $labelTop=shift;
    my $labelBottom=shift;
    my $resultsType="Results in MB/sec";

    my $firstLabel   ="%-10s      ALL  INIT   RE             RE   RANDOM RANDOM BACKWD  RECRE STRIDE";
    my $secondLabel  ="%-10s      IOS  WRITE  WRITE   READ   READ   READ  WRITE   READ  WRITE   READ";
    my $thirdLabel   ="----------------------------------------------------------------------------------";

    if ($numColumns == 13)
	{
	$firstLabel=$firstLabel   . "  F      FRE     F      FRE ";
	$secondLabel=$secondLabel . "  WRITE  WRITE   READ   READ";
	$thirdLabel=$thirdLabel   . "----------------------------";
	}

    if ( $totfiles == 2 )
	{
	$firstLabel ="     " . $firstLabel;
	if ($whichTable eq "Analysis" )
	    {
	    $secondLabel="     " . $secondLabel;
	    $resultsType="Results are % DIFF";
	    }
	else
	    { $secondLabel="FILE " . $secondLabel; }
	$thirdLabel ="=====" . $thirdLabel;
	}

    printf "\nTABLE:  %-55s  %20s\n\n", $tableHeader, $resultsType;

    printf $firstLabel, $labelTop;	print "\n";
    printf $secondLabel, $labelBottom;	print "\n";
    printf $thirdLabel, $labelBottom;	print "\n";
    }

# PRINT A TABLE
#
sub print_res
    {
    my $labenName=shift;
    my @theTable=@_;
    my $ref;

    for (my $idx=0; $idx <= $#theTable; $idx++)
	{
	$ref = @theTable[ $idx ];
	if ( $totfiles > 1 )
	    { printf "%2d   ", $labenName; }
	printf "%9s    ", $ref->{tblName};
	printf "%6d ", $ref->{allIOs};
	for my $iotype ( @ioTypes )
	    { printf "%6d ",$ref->{$iotype}; }
	printf "\n";
	}
    }

# ANALYZE TABLES OF DATA AND REPORT BIG DELTAS
# 
sub analyze_row
    {
    my $isALL=shift;
    my $reportHeader=shift;
    my $pTable1=shift;
    my $pTable2=shift;

    my @l1=@$pTable1;
    my @l2=@$pTable2;

    my $ref1;
    my $ref2;

    my $diff;
    my $percent;
    my @AllioTypes = 'allIOs';
    my $lineName;

    # ANYTHING OUTSIDE OF 5% LOWER PERF OR 2% BETTER IS REPORTED
    # JH FIX - ANYTHING OUTSIDE OF 5% LOWER PERF OR 5% BETTER IS REPORTED
    #
    my $regression=.95;
    my $regression_cnt=0;
    my $improvement=1.05;
    my $improvement_cnt=0;
    my $total_cnt=0;

    # I think the size of the below loop is wrong *******
    push (@AllioTypes, @ioTypes);
    for (my $idx=0; $idx <= $#l1; $idx++)
	{
	$ref1 = $l1[ $idx ];
	$ref2 = $l2[ $idx ];

	if ( $isALL == 1 )
	    { $lineName="ALL"; }
	else
	    { $lineName=$ref1->{tblName}; }
	printf "%14s    ", $lineName;

	for my $iotype ( @AllioTypes )
	    {
	    $total_cnt++;
	    $diff = $ref2->{$iotype} / $ref1->{$iotype};
	    if ($diff > $improvement)
		{
		$percent = ($diff - 1.00) * 100;
		$improvement_cnt++;
		}
	    else
		{
		if ($diff < $regression)
		    {
		    $percent = (1.00 - $diff) * -100;
		    $regression_cnt++;
		    }
		else
		    { $percent=0; }
		}

	    # OUTPUT FORMAT TO MATCH ALL SUMMARY FORMAT
	    #
	    if ( $percent == 0 )
		{ printf "%6s ", "."; }		
	    else
		{ printf "%+6.1f ", $percent; }
	    }
	print "\n";
	}

    if ( $isALL == 0 )
	{
	printf "\n     REGRESSIONS: %d (%3.1f%%)    Improvements: %d (%3.1f%%)\n",
		$regression_cnt,  ($regression_cnt  / $total_cnt) * 100,
		$improvement_cnt, ($improvement_cnt / $total_cnt) * 100;
	}
    }


#####
##### MAIN:
#####

print "\nIOZONE Analysis tool $version\n\n";

# PARSE THE ARGS
#
if ( @ARGV[0] eq "-a" )
    {
    shift;
    $printRecFileAnalysis=0;
    }

if ( @ARGV[0] eq "-h"  | $#ARGV < 0 | $#ARGV > 1 )
    { &help_msg(); }

# LIST FILE NUMBER / NAME RELATIONSHIP AND GET TOTAL FILE COUNT
#
$filenum=0;
for my $fileName ( @ARGV )
    {
    $filenum++;
    printf "FILE %d: %s\n", $filenum, $fileName;
    }
$totfiles=$filenum;

$filenum=0;
for my $fileName ( @ARGV )
    {
    if ( ! open FILEHANDLE, $fileName )
	{
	print "\nError - Cant Open $fileName\n";
	&help_msg();
	}

    $filenum++;

    # NOW BLOW AWAY RESULTS FOR NEW FILE
    #
    &init_rows();

    while ( <FILEHANDLE> )
	{
	# THROW AWAY ANY PRIOR STUFF IN THE FILE
	#
	if ( $skipStuff eq 1 && !/^	Iozone:/ )
	    { next; }

	$skipStuff=0;

	# SKIP ALL LINES WITH TABS.  DATA LINES USE SPACES
	#
	if ( !/^	/ )
	    {
	    # SKIP LINES WITHOUT TABS BUT HAVE TEXT; THESE ARE THE
	    # HEADER LINES FOR THE TABLES.  SKIP EMPTY LINES AS WELL.
	    #
	    if (/ +[a-z]/)
		{ next; }
	    if (/^$/)
		{ next; }

	    # SEPERATE THE DATA INTO SEPERATE SCALAR VALUES AND SAVE THEM IN A ROW
	    #
	    my ($blankspace,$file_size,$rec_size,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$d8,$d9,$d10,$d11,$d12,$d13)=split /\s+/,$_;

	    # LAYOUT FIELDS BASED ON FIRST DATA LINE COLUMN COUNT.  FOR NOW WE SUPPORT
	    # TWO FORMATS ... FULL FORMAT AND MMAP WHICH DOESN'T DO FWRITE ETC.
	    if ( $lines == 0 )
		{
		@ioTypes=('iwrite', 'rewrite', 'iread', 'reread', 'randrd', 'randwr', 'bkwdrd', 'recrewr', 'striderd');
		if ($d13 ne "")
		    { push (@ioTypes, 'fwrite', 'frewrite', 'fread', 'freread'); }

		$numColumns=$#ioTypes+1;
		if ($filenum > 1 && $numColumns != $numColumns1)
		    { printf "\nError - Files not in same format (run types) cannot be analyzed ... quiting\n";	exit; }
		}

	    # IF THERES A MISSING FIELD WHERE THERE SHOULD BE ONE, THEN ERROR
	    #
	    if (($d13 eq "" && $numColumns == 13) || ($d9 eq "" && $numColumns == 9))
		{ print "Warning - Incomplete record (skipping): $_"; next; }

	    push @row_iozone, { KB=>$file_size, reclen=>$rec_size, iwrite=>$d1, rewrite=>$d2, iread=>$d3,
		reread=>$d4, randrd=>$d5, randwr=>$d6, bkwdrd=>$d7, recrewr=>$d8, striderd=>$d9, fwrite=>$d10,
		frewrite=>$d11, fread=>$d12, freread=>$d13 };

	    &mult_row( @all_geomean[0], @row_iozone[$lines] );

	    # DETERMINE RANGE OF RESULTS
	    #
	    if ( &inlist( $rec_size, @rec_sizes ) == 1 )
		{
		push (@rec_sizes, $rec_size);
		push @recsize_geomean, { tblName=>$rec_size, rec_size=>$rec_size, numItems=>0,
			iwrite=>$bigNum, rewrite=>$bigNum, iread=>$bigNum, reread=>$bigNum, randrd=>$bigNum, randwr=>$bigNum,
			bkwdrd=>$bigNum, recrewr=>$bigNum, striderd=>$bigNum, fwrite=>$bigNum, frewrite=>$bigNum,
			fread=>$bigNum, freread=>$bigNum, allIOs=>$bigNum };
		}
	    if ( &inlist( $file_size, @file_sizes ) == 1 )
		{
		push (@file_sizes, $file_size);
		push @filesize_geomean, { tblName=>$file_size, file_size=>$file_size, numItems=>0,
			iwrite=>$bigNum, rewrite=>$bigNum, iread=>$bigNum, reread=>$bigNum, randrd=>$bigNum, randwr=>$bigNum,
			bkwdrd=>$bigNum, recrewr=>$bigNum, striderd=>$bigNum, fwrite=>$bigNum, frewrite=>$bigNum,
			fread=>$bigNum, freread=>$bigNum, allIOs=>$bigNum };
		}

	    if ( $printRecFileAnalysis == 1 )
		{
		$row2update = &find_row( 'rec_size', $rec_size, @recsize_geomean );
		&mult_row( @recsize_geomean[$row2update], @row_iozone[$lines] );

		$row2update = &find_row( 'file_size', $file_size, @filesize_geomean );
		&mult_row( @filesize_geomean[$row2update], @row_iozone[$lines] );
		}

	    $lines++;
	    }
	}

    close(FILEHANDLE);

    # SAVE MIN MAX OF THIS DATA SET
    #
    $min_recsize  = min @rec_sizes;
    $max_recsize  = max @rec_sizes;
    $min_filesize = min @file_sizes;
    $max_filesize = max @file_sizes;

    # NTH ROOT OF VARIOUS TABLES AND OUTPUT
    #
    &nroot_row ( @all_geomean );
    if ( $printRecFileAnalysis == 1)
	{
	&nroot_row ( @recsize_geomean );
	&nroot_row ( @filesize_geomean );
	}

    if ( $filenum == 1 )
	{ &print_header( 'ALL', 'SUMMARY of ALL FILE and RECORD SIZES', 'FILE & REC', 'SIZES (KB)' ); }
    &print_res ( $filenum, @all_geomean );

    # SAVE RESULTS FIRST TIME FOR COMPARISON ON THE SECOND FILE IF ANY.
    #
    if ( $filenum == 1 )
	{
	@all_geomean1 = @all_geomean;
	@all_geomean_cmp = @all_geomean;

	@recsize_geomean1 = @recsize_geomean;
	@recsize_geomean_cmp = @recsize_geomean;

	@filesize_geomean1 = @filesize_geomean;
	@filesize_geomean_cmp = @filesize_geomean;

	$min_recsize1  = $min_recsize;
	$max_recsize1  = $max_recsize;
	$min_filesize1 = $min_filesize;
	$max_filesize1 = $max_filesize;

	$numColumns1 = $numColumns;
	}
    }

# ANALYZE ALL ROWS AND OUTPUT AS SUMMARY LINE
#
if ($filenum > 1)
    {
    my $ok2continue = 1;
    if ( (($min_recsize1 - $min_recsize) +
	  ($max_recsize1  - $max_recsize)) != 0 )
	{
	print "\nError - Files have a different range of record sizes.\n";
	print "  FILE 1: [$min_recsize1 KB - $max_recsize1 KB]\n  FILE 2: [$min_recsize KB - $max_recsize KB]\n";
	$ok2continue = 0;
	}

    if ( (($min_filesize1 - $min_filesize) +
	  ($max_filesize1 - $max_filesize)) != 0 )
	{
	print "\nError - Files have a different range of file sizes.\n";
	print "  FILE 1: [$min_filesize1 KB - $max_filesize1 KB]\n  FILE 2: [$min_filesize KB - $max_filesize KB]\n";
	$ok2continue = 0;
	}

    if ( $numColumns1 != $numColumns )
	{
	print "\n Error - Columns of data do not match between files.\n";
	print "  FILE 1: $numColumns1 columns\n  FILE 2: $numColumns columns\n";
        $ok2continue = 0;
	}

    if ( $ok2continue != 1 )
	{
	print "Cannot continue ...\n";
	exit 2;
	}

    &analyze_row ( 1, "ALL RECsize and FILEsize analysis", \@all_geomean1, \@all_geomean);
    }


# PRINT OUT FILESIZE AND RECORD SIZE GEOMEAN TABLES
#
if ( $printRecFileAnalysis == 1)
    {
    print "\n\nDRILLED DATA:\n";
    &print_header( 'RECORD', 'RECORD Size against all FILE Sizes', 'RECORD', 'SIZE (KB)' );
    &print_res ( 1, @recsize_geomean1 );
    print "\n";
    if ( $totfiles > 1 )
	{ &print_res ( 2, @recsize_geomean ); }

    &print_header( 'FILE', 'FILE Size against all RECORD Sizes', 'FILE', 'SIZE (KB)' );
    &print_res ( 1, @filesize_geomean1 );
    print "\n";
    if ( $totfiles > 1 )
	{ &print_res ( 2, @filesize_geomean ); }
    }

# ANALYZE FILE AND REC TABLES AND OUTPUT AS LIST
#
if ($filenum > 1)
    {
    if ( $printRecFileAnalysis == 1)
	{
	print "\n\nANALYSIS OF DRILLED DATA:\n";
	&print_header( 'Analysis', 'RECsize Difference between runs', 'RECORD', 'SIZE (KB)' );
	&analyze_row ( 0, "RECsize analysis against all FILEsizes", \@recsize_geomean1, \@recsize_geomean);
	&print_header( 'Analysis', 'FILEsize Difference between runs', 'FILE', 'SIZE (KB)' );
	&analyze_row ( 0, "FILEsize analysis against all RECsizes",  \@filesize_geomean1, \@filesize_geomean);
	}
    }

exit;
