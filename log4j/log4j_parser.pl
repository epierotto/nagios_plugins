#! /usr/bin/perl -w
#
use POSIX qw(strftime);
use Nagios::Plugin;

$VERSION = "2.0.0";

$blurb = "This plugin retrieves data from log lines matching labels and columns in a time frame, also you can set thresholds for each of label.";

$license = "This nagios plugin is free software, and comes with ABSOLUTELY NO WARRANTY. It may be used, redistributed and/or modified under the terms of the GNU General Public Licence (see http://www.fsf.org/licensing/licenses/gpl.txt).";

my $np;

$np = Nagios::Plugin->new(usage => "Usage: %s [-p|--path <complete path to log file>] [-s|--string <labels to search for>] [-m|--minutes <ammount of minutes before the actual date to set the time frame>] [-C|--column <name of the column to retrieve the data>] [-d|--date-format <date format>] [-n|--column-names <set names for each log column>] [-w|--warning <warning threshold>] [-c|--critical <critical threshold>] [-?|--usage] [-V|--version] [-h|--help] [-t|--timeout=<timeout>]",
                        version => $VERSION,
                        blurb   => $blurb,
                        license => $license,
                        );

$np->add_arg(spec => 'path|p=s',
             help => q(Complete path to the log file),
             required => 1,
            );

$np->add_arg(spec => 'string|s=s',
             help => q(Labels or tags to search in the log file, separated with "+" from each other),
             required => 1,
            );

$np->add_arg(spec => 'minutes|m=i',
             help => q(Ammount of minutes before the actual date to set a range of time. Default 1 min),
             required => 0,
             default => 1,
            );

$np->add_arg(spec => 'column|C=s',
             help => q(Name of the column to pick up the value. Default value: Count),
             required => 0,
             default => "5",
            );

$np->add_arg(spec => 'date-format|d=s',
             help => q(Date format of the log file based on POSIX strftime. Default is "%Y-%m-%d %H:%M:"),
             required => 0,
             default => "%Y-%m-%d %H:%M:",
            );

$np->add_arg(spec => 'column-names|n=s',
             help => q(You can set names for each log column, separated with "+" from each other. Default value is: 0+1+2+3+4+5),
             required => 0,
             default => "0+1+2+3+4+5",
            );

$np->add_arg(spec => 'critical|c=s',
             help => q(Values for the Critical Thresholds separated with "+". The ammount of given criticals thresholds must match the ammount of labels to check. http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT),
             required => 0,
            );

$np->add_arg(spec => 'warning|w=s',
             help => q(Values for the Warning Thresholds separated with "+". The ammount of given warnings thresholds must match the ammount of labels to check. http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT),
             required => 0,
            );

# Parse and process arguments
$np->getopts;
$ng = $np->opts;

# Manage timeout
alarm $ng->timeout;

# Arguments processing 
$file = $ng->get('path');
@LABELS = split(/\+/, $ng->get('string'));
$minutes_before = $ng->get('minutes');
$date_format = $ng->get('date-format');
@column_names = split(/\+/,$ng->get('column-names'));
$REGEX_columns = join("|", @column_names);
$REGEX_labels = join("|", @LABELS);

# Building the thresholds if any
if ($ng->get('warning') or $ng->get('critical')){
        if ($ng->get('warning')){
                @warnings = split(/\+/,$ng->get('warning'));
        }
        if ($ng->get('critical')){
                @criticals = split(/\+/,$ng->get('critical'));
        }
        eval ($#warnings==$#LABELS and $#criticals==$#LABELS) or $np->nagios_exit( CRITICAL,"You must provide a warning and critical threshold per tag or no thresholds at all, check your thresholds!");
}

# Checking performance data columns
if ($ng->get('column') and $ng->get('column') =~/$REGEX_columns/){
	$column_selected = $&;
} else {
	$np->nagios_exit( CRITICAL,"Chosen column \"".$ng->get('column')."\" not available. Options are: @column_names");
}

# Date formatting
$timestamp_before = time - ($minutes_before * 60);
$before = strftime "$date_format", localtime($timestamp_before);
$now = strftime "$date_format", localtime;


# Reading the file
open (FILE,$file) or $np->nagios_exit( CRITICAL, "Unable to read $file");
        while (<FILE>) {
                next unless /$before\d\d/../$now\d\d/ and /\b$REGEX_labels\b/ and $tag = $&;
		@COLUMNS{@column_names} = split(/\s+/,$_);
		$PERFDATA{$tag} = $COLUMNS{$column_selected};
        }
close FILE or $np->nagios_exit( CRITICAL, "ERROR while closing $file");


# Initial message and status
my $code = OK;
my $msg = $np->add_message($code,"All stats retrieved");

# Loading retrieved data
foreach $label (@LABELS){
        defined $PERFDATA{$label} or $PERFDATA{$label} = 0;
        $np->add_perfdata(
                label => $label,
                value => $PERFDATA{$label},
                );
        # Checking thresholds
        if (@warnings and @criticals){
                $warning = shift @warnings;
                $critical = shift @criticals;
                $code = $np->check_threshold( check => $PERFDATA{$label}, warning => $warning, critical => $critical);
                $msg = $np->add_message($code,"$label=$PERFDATA{$label} W=$warning C=$critical") if $code != OK;
                }
}

# Exit
($code, $msg) = $np->check_messages();
$np->nagios_exit( $code, $msg );
