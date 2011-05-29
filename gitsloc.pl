use strict;
use warnings;

use Sysadm::Install qw(:all);
use Text::CSV_XS;

my $csv;

my ( $cvs_handler, $report_filename, $project_directory ) = init();
cd( $project_directory );

my @revs = get_revisions();

my %report    = ();
my %languages = ();

foreach my $r ( reverse @revs ) {
    tap( "git", "checkout", $r );
    my ( $cloc_output, undef, undef ) = tap( "cloc", "--csv", "." );   

    my @lines = split /\n/, $cloc_output; 

    foreach ( @lines ) {
    	next unless /^\d+,\w+/;

    	my (undef, $lang, $blank, $comment, $code) = split /,/;

    	$languages{ $lang } += $code;

    	$report{ $r }->{ $lang } = {
    		blank   => $blank,
    		comment => $comment, 
    		code    => $code
        };
    }

    say "Done $r";
}

report( $cvs_handler, $report_filename );
tap( "git", "checkout", "master" );


sub report {
	my $csv = shift;
	my $report_filename = shift;

    open my $fh, ">:encoding(utf8)", $report_filename or die "$report_filename $!";

    my @lang_list = keys %languages;
    $csv->print( $fh, [ "Revision", @lang_list ] ); 

    foreach my $r ( reverse @revs ) {
        $csv->print( $fh, [ $r, map( +$report{ $r }->{ $_ }->{ 'code' }, @lang_list) ] );
    }
    close $fh;
}


sub get_revisions {

    my($stdout, $stderr, $exit_code) = tap( "git", "log", "--oneline" );

    my @revs = map   { $_->[0] } 
               map   { [split / /] } 
               split /\n/, $stdout;

    return @revs;
}


sub init {
    my $csv = Text::CSV_XS->new( { binary => 1 } ) or
        die "Cannot use CSV: ".Text::CSV_XS->error_diag;
    $csv->eol("\r\n");

    my $default_project_directory = qq{.};
    my $default_report_filename   = "/tmp/report.csv";

    my $project_directory = ask( "Project directory", $default_project_directory );
    my $report_filename = ask( "Report filename", $default_report_filename );

    return ($csv, $report_filename, $project_directory);
}
