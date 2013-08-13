#!/usr/bin/perl -w

use warnings;
use strict;
use Getopt::Long qw(:config gnu_getopt);
use File::Basename;
use Sys::Hostname;
use Nagios::Plugin;
my $VERSION="1.2.1";
my $np;

$np = Nagios::Plugin->new(usage => "Usage: %s [--path|-p <path>] [-s|--string <string>] [--column|-C <column>] [-w|--warning <string>] [-c|--critical <string>] [-?|--usage] [-V|--version] [-h|--help] [-v|--verbose] [-t|--timeout=<timeout>]",
                          version => $VERSION,
                          blurb => 'This plugin retrieves the values of the given strings from the given log file, also you can check thresholds for each string.http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT',
                          license => "Brought to you AS IS, WITHOUT WARRANTY, under GPL. (C)",
                          shortname => "PARSE_LOG",
                         );

$np->add_arg(spec => 'path|p=s',
             help => q(Complete path to the log file, indicated in STRING),
             required => 1,
            );

$np->add_arg(spec => 'string|s=s',
             help => q(Values or strings to seach for separated with "+", indicated in STRING),
             required => 1,
            );

$np->add_arg(spec => 'column|C=i',
             help => q(This is the number of column to retrieve the values. Default value is 5),
             required => 0,
	     default => 5,
            );

$np->add_arg(spec => 'critical|c=s',
             help => q(Values for the Critical Thresholds separated with "+". The ammount of given criticals thresholds must match with the ammount of strings to check. http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT),
             required => 0,
            );

$np->add_arg(spec => 'warning|w=s',
             help => q(Values for the Warning Thresholds separated with "+". The ammount of given warnings thresholds must match with the ammount of strings to check. http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT),
             required => 0,
            );

# Getting the opts
$np->getopts;
my $ng = $np->opts;

# Manage timeout
alarm $ng->timeout;

# Verbosity
my $verbose = $ng->get('verbose');

# Options
my $path = $ng->get('path');
my @strings = split(/\+/,$ng->get('string'));
my @warnings;
my @criticals;
my $column = $ng->get('column');

# Building the thresholds
if (defined $ng->get('warning') && $ng->get('critical')) {
        @warnings = split(/\+/,$ng->get('warning'));
        @criticals = split(/\+/,$ng->get('critical'));
eval ($#warnings==$#strings and $#criticals==$#strings) or $np->nagios_exit(CRITICAL,"You should specify the same amount of warnings, criticals and strings.");
}

# Taking the date with the right format
my $date = `date "+%F %H:%M:00" -d "1 min ago"`;
$date =~s/\n//g;
# Retrieving the data from the log
eval (my @lines = `grep -A 200 "$date" $path`) or $np->nagios_exit( CRITICAL, "Unable to get values from $path");

# Initial message and status
my $code = OK;
my $msg = $np->add_message($code,"All stats retrieved");

# And here we go!
foreach my $label (@strings){
	my $value = 0;
	my $j = 1;

	# Reading the retrieved lines
	foreach (@lines){
                my @lineparsed=split(/\s+/,$_);
                        if (defined ($lineparsed[0]) && $lineparsed[0] eq $label){
				$value = $lineparsed[$column];
                                        $np->add_perfdata(
                                               label => $label,
                                               value => $value,
                                        );
                                        last;
                        }
                        else {
                                if ($j == $#lines){
					$np->add_perfdata(
                                               label => $label,
                                               value => $value,
                                        );
                                }
                        }
	$j++;
	}

	# Checking thresholds
	if (@warnings and @criticals){
		my $warning = shift @warnings;
		my $critical = shift @criticals;
		if (defined $warning and $critical){
			$code = $np->check_threshold( check => $value, warning => $warning, critical => $critical);
			$msg = $np->add_message($code,"$label=$value W=$warning C=$critical") if $code != OK;
		}
	}
}

# Exit
($code, $msg) = $np->check_messages();
$np->nagios_exit( $code, $msg );
