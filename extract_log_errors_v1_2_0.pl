@rem = '--*-Perl-*--
@echo off

perl -x -S "%0" %1 %2 %3 %4 %5 %6 %7 %8 %9
goto endofperl
@rem ';
#!/usr/local/bin/perl -w
#
# description:
#   extract error messages from XML log and GLog file
#   - extract header info from XML log
#   - extract processed TP objects and detail error messages from GLog file 
#   precondition:
#   - all SGML files are converted to normalized structure (clear job),
#     i.e. all start tags with PCDATA content are closed by an end tag (no omitted start or end tags).
# start:
#   extract_log_errors.pl <log_file>
# parameter:
#   log_file - path and file name to XML log file of XService job
#
# 04.02.2015 paul g.
#
# data structure:
#
# mods:
# 10.03.2015  paul g. extract error messages from GLog file
#                     file naming of output file corresponds to job name
# 14.07.2015  paul g. moved data storage from hash to array
#                     include element path to error message output
# 

use strict;
use Data::Dumper;

# -------------------------------------------------------
# check parameter
# -------------------------------------------------------
sub check_parameter {
  my $xs_log_file = shift;

  my $i_valid = 1;
  
  if ( $xs_log_file eq "" ) {
    print "ERROR: Log file not defined\n";
    $i_valid = 0;
    }
  if ( ! -e $xs_log_file ) {
    print "ERROR: Log file not found\n";
    $i_valid = 0;
    }

  return( $i_valid );
  }
  
# -------------------------------------------------------
# show parameter
# -------------------------------------------------------
sub show_parameter {
  my $xs_log_file = shift;

  my $i_valid = 1;
  my %data;
  my $s_header = "------------- extract log errors --------------\n";
  
  print $s_header;
  print "Parameter 1: Log file = (" . $xs_log_file . ")\n";
  print $s_header;

  return( $i_valid );
  }
  
# -------------------------------------------------------
# read xml log file
# -------------------------------------------------------
sub read_xml_log_file {
  my $xs_file = shift;
  my $xp_data = shift;

  my $i_valid = 1;
  my $s_line = "";
  my $s_buffer = "";
  my $s_temp ="TEMP";

  $xp_data->{ $s_temp }{ "VALID"} = 1;
  
  print "\nReading log file " . $xs_file . "\n";
  if ( open( LOG1, "< $xs_file" ) ) {
    while( $s_line = <LOG1> ) {
      chomp( $s_line );
      $s_buffer .= $s_line . " ";
      }
    close( LOG1 );

    $s_buffer =~ s/(\<ASDJobLog.*?\>)/extract_elem_asdjoblog_start( $1, $xp_data )/eg;

    if ( $xp_data->{ $s_temp }{ "VALID"} == 0 ) { $i_valid = $xp_data->{ $s_temp }{ "VALID"}; }    
    }
  else {
    print "ERROR: cannot open log file ( $xs_file )\n";
    $i_valid = 0;
    }
    
  $s_buffer = "";

  ### print "------------- START TRACE LOG FILE --------------\n";
  ### print Dumper( \%{ $xp_data->{ $s_type } } );
  ### print "------------- END TRACE LOG FILE --------------\n";

  return( $i_valid );
  }

# -------------------------------------------------------
# read glog file
# -------------------------------------------------------
sub read_glog_file {
  my $xs_file = shift;
  my $xp_data = shift;

  my $i_valid = 1;
  my $s_line = "";
  my $s_buffer = "";
  my $s_temp ="TEMP";
  my $s_file = $xs_file;

  $xp_data->{ $s_temp }{ "VALID"} = 1;
  $s_file =~ s/ASDJobLog/GLog/;
  print "\nReading log file " . $s_file . "\n";
  if ( open( LOG2, "< $s_file" ) ) {
    while( $s_line = <LOG2> ) {
      chomp( $s_line );
      $s_buffer .= $s_line . " ";
      }
    close( LOG2 );

    $xp_data->{ "COUNT" }{ "DM" } = 0;
    $s_buffer =~ s/(\<level0.*?\<\/level0\>)/extract_elem_level0( $1, $xp_data )/eg;
    print $xp_data->{ "COUNT" }{ "DM" } . " data modules processed\n"; 

    if ( $xp_data->{ $s_temp }{ "VALID"} == 0 ) { $i_valid = $xp_data->{ $s_temp }{ "VALID"}; }    
    }
  else {
    print "ERROR: cannot open log file ( $s_file )\n";
    $i_valid = 0;
    }
    
  $s_buffer = "";

  ### print "------------- START TRACE ERRORS --------------\n";
  ### print Dumper( \%{ $xp_data->{ "ERRORS" } } );
  ### print "------------- END TRACE ERRORS --------------\n";

  return( $i_valid );
  }

# -------------------------------------------------------
# write error file
# -------------------------------------------------------
sub write_error_file {
  my $xs_log_file = shift;
  my $xp_data = shift;

  my $i_valid = 1;
  my $s_path = $xs_log_file;
  my $s_file = "";
  my $s_errors = "ERRORS";
  my $s_filename = "";
  my $s_text = "";
  my $s_jobname = $xp_data->{ "META" }{ "JOBNAME" };
  my $s_jobtype = $xp_data->{ "META" }{ "JOBTYPE" };
  my $i_count = 0;
    
  $s_path =~ s/[^\\]+$//;           # remove file name and extension
  $s_file = $s_jobname . "_errors_only.htm";
  $s_file =~ s/[ \t]/_/g;
  if ( $s_path ne "" ) {
    if ( $s_path =~ /\\$/ ) {
      $s_file = $s_path . $s_file;
      }
    else {
      $s_file = $s_path . "\\" . $s_file;
      }
    }
  
  print "\nWriting error file " . $s_file . "\n";
  if ( open( ERR, "> $s_file" ) ) {
    print ERR "<html><head><title>Transfer Package with Errors</title></head><body>\n";
    print ERR "<h3>" . $s_jobname . "</h3><hr>\n";
    if ( $s_jobtype eq "TPNH90CheckerJob" ) {
      print ERR "<p><font color=\"#000000\" size=\"2\">Overview of checks (processed items - passed checks - warnings - errors)</font></p>\n";
      }
    foreach $s_filename ( sort keys %{ $xp_data->{ $s_errors } } ) {
      $i_count = scalar @{ $xp_data->{ $s_errors }{ $s_filename } };
      if ( $i_count > 0 ) {                    # only create output if error messages stored
        print ERR "<h3>" . $s_filename . "</h3>\n";
        foreach $s_text ( @{ $xp_data->{ $s_errors }{ $s_filename } } ) {
          $s_text =~ s/\&apos;/'/ig;
          print ERR "<p><font color=\"#FF0000\" size=\"2\">" . $s_text . "</font></p>\n"; 
          }
        print ERR "<hr>\n";
        } 
      }
    print ERR "</body></html>\n";
    close( ERR );
    }
  else {
    print "ERROR: cannot open error file ( $s_file )\n";
    $i_valid = 0;
    }
    
  return( $i_valid );
  }

# -------------------------------------------------------
# extract start tag of element ASDJobLog
# -------------------------------------------------------
sub extract_elem_asdjoblog_start {
  my $xs_content = shift;
  my $xp_data = shift;

  my $i_valid = 1;
  my $s_temp = "TEMP";
  my $s_jobname = "";
  my $s_jobtype = "";
  
  $xp_data->{ "TEMP" }{ "ATTR" }{ "jobname" } = "";
  $xp_data->{ "TEMP" }{ "ATTR" }{ "jobtype" } = "";
  $xs_content =~ s/(\<ASDJobLog.*?\>)/extract_attr( "jobname", $1, $xp_data )/ieg;
  $xs_content =~ s/(\<ASDJobLog.*?\>)/extract_attr( "jobtype", $1, $xp_data )/ieg;
  if ( defined( $xp_data->{ "TEMP" }{ "ATTR" }{ "jobname" } ) ) {
    $s_jobname = $xp_data->{ "TEMP" }{ "ATTR" }{ "jobname" };
    }
  if ( defined( $xp_data->{ "TEMP" }{ "ATTR" }{ "jobtype" } ) ) {
    $s_jobtype = $xp_data->{ "TEMP" }{ "ATTR" }{ "jobtype" };
    }
  $xp_data->{ "META" }{ "JOBNAME" } = $s_jobname;
  $xp_data->{ "META" }{ "JOBTYPE" } = $s_jobtype;
  print "Job name: " . $s_jobname . "\n"; 
  print "Job type: " . $s_jobtype . "\n"; 
    
  if ( $i_valid == 0 ) { $xp_data->{ $s_temp }{ "VALID"} = $i_valid; }
  return( "" );
  }

# -------------------------------------------------------
# extract element level0
# -------------------------------------------------------
sub extract_elem_level0 {
  my $xs_content = shift;
  my $xp_data = shift;

  my $i_valid = 1;
  my $s_temp = "TEMP";
  my $s_file = "";
  my @buffer = ();
  
  $xp_data->{ "COUNT" }{ "DM" }++;
  $xp_data->{ "TEMP" }{ "ATTR" }{ "file" } = "";
  $xs_content =~ s/(\<level0.*?\>)/extract_attr( "file", $1, $xp_data )/eg;
  if ( defined( $xp_data->{ "TEMP" }{ "ATTR" }{ "file" } ) ) {
    $s_file = $xp_data->{ "TEMP" }{ "ATTR" }{ "file" };
    }
  if ( $s_file ne "source" ) {
    print "DM: " . $s_file . "\n";

    if ( ! exists( $xp_data->{ "ERRORS" }{ $s_file } ) ) {
      $xp_data->{ "ERRORS" }{ $s_file } = \@buffer; 
      }
    $xs_content =~ s/(\<msg.*?\<\/msg\>)/extract_elem_msg( $1, $s_file, $xp_data )/eg;
    }
    
  if ( $i_valid == 0 ) { $xp_data->{ $s_temp }{ "VALID"} = $i_valid; }
  return( "" );
  }

# -------------------------------------------------------
# extract element msg
# -------------------------------------------------------
sub extract_elem_msg {
  my $xs_content = shift;
  my $xs_filename = shift;
  my $xp_data = shift;

  my $i_valid = 1;
  my $s_temp = "TEMP";
  my $s_type = "";
  my $s_text = "";
  
  $xp_data->{ "TEMP" }{ "ATTR" }{ "type" } = "";
  $xs_content =~ s/(\<msg.*?\>)/extract_attr( "type", $1, $xp_data )/eg;
  if ( defined( $xp_data->{ "TEMP" }{ "ATTR" }{ "type" } ) ) {
    $s_type = $xp_data->{ "TEMP" }{ "ATTR" }{ "type" };
    }
  if ( $s_type eq "error" ) {
    $s_text = "";
    if ( $xs_content =~ /\<msg.*?\>(.*?)\<\/msg\>/ ) {
      $s_text = $1;
      }
    print "ERROR: " . $s_text . "\n";
    push( @{ $xp_data->{ "ERRORS" }{ $xs_filename } }, $s_text );
    $xp_data->{ $s_temp }{ "PATH" } = "";
    }
  elsif ( $s_type eq "info" ) {
    $s_text = "";
    if ( $xs_content =~ /\<msg.*?\>(.*?)\<\/msg\>/ ) {
      $s_text = $1;
      }
    if ( $s_text =~ /\[[0-9]+\]/ ) {            # should contain element path to error
      print "INFO: " . $s_text . "\n";
      push( @{ $xp_data->{ "ERRORS" }{ $xs_filename } }, $s_text );
      } 
    }
    
  if ( $i_valid == 0 ) { $xp_data->{ $s_temp }{ "VALID"} = $i_valid; }
  return( "" );
  }

# -------------------------------------------------------
# extract attribute
# -------------------------------------------------------
sub extract_attr {
  my $xs_name = shift;
  my $xs_content = shift;
  my $xp_data = shift;

  my $i_valid = 1;
  my $s_pattern = "(?:###EOL###| )" . $xs_name . "[ \\t]*=[ \\t]*\"(.*?)\"";

  $xs_content =~ s/$s_pattern/extract_attr_value( $xs_name, $1, $xp_data )/ieg;

  if ( $i_valid == 0 ) { $xp_data->{ "TEMP"}{ "VALID"} = $i_valid; }
  return( $xs_content );    # return of matching text is required, because there are more than one attribute for a element
  }

# -------------------------------------------------------
# extract attribute value
# -------------------------------------------------------
sub extract_attr_value {
  my $xs_name = shift;
  my $xs_value = shift;
  my $xp_data = shift;

  my $i_valid = 1;
  my $s_temp = "TEMP";
  
  $xp_data->{ $s_temp }{ "ATTR" }{ $xs_name } = $xs_value;
  
  if ( $i_valid == 0 ) { $xp_data->{ $s_temp }{ "VALID"} = $i_valid; }
  return( " " . $xs_name . "=\"" . $xs_value . "\"" );
  }

# -------------------------------------------------------
# convert_data
# -------------------------------------------------------
sub convert_data {
  my $xs_content = shift;

  my $i_valid = 1;
  
  if ( defined( $xs_content ) ) {
    $xs_content =~ s/###EOL###//ig;     # remove end of line
    }
  
  return( $xs_content );
  }

# -------------------------------------------------------
# convert_data2
# -------------------------------------------------------
sub convert_data2 {
  my $xs_content = shift;

  my $i_valid = 1;
  
  if ( defined( $xs_content ) ) {
    $xs_content =~ s/###EOL###/ /ig;     # substitute to one blank
    $xs_content =~ s/'/''/ig;            # substitute sql delimiter
    }
  
  return( $xs_content );
  }
  
# -------------------------------------------------------
# delete index
# -------------------------------------------------------
sub delete_index {
  my $xp_hash = shift;

  my $i_valid = 1;
  my $s_elem = "";
  
  foreach $s_elem ( keys %{ $xp_hash } ) {
    delete( $xp_hash->{ $s_elem } );
    }
  
  return( $i_valid );
  }
  
# -------------------------------------------------------
# set attribute string
# -------------------------------------------------------
sub set_attribute {
  my $xs_name = shift;
  my $xs_value = shift;

  my $i_valid = 1;
  my $s_sgml = "";
  
  if ( $xs_value ne "" ) {
    $s_sgml = " " . $xs_name . "=\"" . $xs_value . "\"";
    }
  
  return( $s_sgml );
  }  

# -------------------------------------------------------
# set line feed
# -------------------------------------------------------
sub set_line_feed {
  my $xs_content = shift;

  my $i_valid = 1;
  
  if ( defined( $xs_content ) ) {
    $xs_content =~ s/###EOL###/\n/ig;     # set end of line
    }
  
  return( $xs_content );
  }
  
# -------------------------------------------------------
# remove line feed
# -------------------------------------------------------
sub remove_line_feed {
  my $xs_content = shift;

  my $i_valid = 1;
  
  if ( defined( $xs_content ) ) {
    $xs_content =~ s/###EOL###//ig;     # remove end of line
    }
  
  return( $xs_content );
  }

# -------------------------------------------------------
# get base dir
# -------------------------------------------------------
sub get_base_dir {
  my $xs_content = shift;

  my $i_valid = 1;
  my $s_dir = $xs_content;
  
  if ( $s_dir =~ /\\/ ) {
    $s_dir =~ s/\\[^\\]+$//;     # remove file name and extension
    }
  else {
    $s_dir = ".";
    }
  
  return( $s_dir );
  }

# ------------------------- main ------------------
my $xs_log_file = $ARGV[ 0 ] || "";
my $i_valid = 1;
my $i_valid_save = 1;
my $i_trace = 1;
my %data;

if ( $i_valid == 1 ) {
  $i_valid = check_parameter( $xs_log_file );
  }
if ( $i_trace == 1 ) {
  $i_valid_save = show_parameter( $xs_log_file );
  if ( $i_valid_save == 0 ) { $i_valid = $i_valid_save; }
  }
if ( $i_valid == 1 ) {
  $i_valid = read_xml_log_file( $xs_log_file, \%data );
  }
if ( $i_valid == 1 ) {
  $i_valid = read_glog_file( $xs_log_file, \%data );
  }
if ( $i_valid == 1 ) {
  $i_valid = write_error_file( $xs_log_file, \%data );
  }
  
if ( $i_valid == 1 ) {
  print "successfully ended\n";
  exit;
  }
else {
  print "ended with errors\n";
  exit( 1 );
  }

__END__
:endofperl
