Nagios Plugins :: nagios-plugins
================================

Description
------------

`nagios-plugins` pretend to be a collection of various customized plugins my mates
and I have written and expanded over the last 2 years or so, working a monitoring
area in a pretty popular company.

They have mostly written in Perl/Bash

Overview of Available Plugins
-----------------------------

### log4j\_parser.pl 
This plugin retrieves data from log lines matching labels and columns in a time frame, also you can set thresholds for each of label.

* Example of use:
Suposse that you have to parse a log file with the following format:

>Performance Statistics   2013-08-26 17:04:00 - 2013-08-26 17:05:00
>Tag                                  Avg(ms)         Min         Max     Std Dev       Count
>label1                                  0.0           0           0         0.0           2
>label2                                  0.5           0           1         0.5           2
>label3                                  0.2           0         134         2.9        2588
>label4                                  5.0           5           5         0.0           1
label5                                 12.3          10          18         2.2          15
>label6                                 38.1           0         996        63.3        1765
>label7                                  0.4           0          24         2.1         192

