package DataStore;
# this module implements the accesses to the comScore Programming Challenge
# datastore.  There's a lot of die's & warns in this code, in production code this should
# really be logs to an event log.

use strict;
use warnings;

use Text::CSV;
use Exporter;

our @EXPORT_OK = qw(saveTsv query @visible_headers);

my $filename = "datastore.csv";
our @visible_headers = qw(STB TITLE PROVIDER DATE REV VIEW_TIME);
my @headers = qw(KEY STB TITLE PROVIDER DATE REV VIEW_TIME);
my $sep = '|';


sub trim {
  my ($str) = @_;

  $str =~ s/^\s+|\s+$//g;
  return $str;
}

# simply concatenate the trimmed values.  There's an opportunity to compress or hash, but
# it's simpler just to concatenate, and since I only have a few hours to do
# this, I'll just concatenate.  Use pipes as separators because the source
# file uses pipes as separators
sub compositeKey {
  return join($sep, map {trim($_)} @_);
}

# import the data from the import file into the datastore in the given data directory.
# In the case where an import entry has the same composite key (stb, title, date)
# as an entry in the datastore, the data from the import file overwrites the
# existing entry.
sub saveTsv {
  my ($dataDir, $importFile) = @_;

  my $dataFile = "$dataDir/$filename";
  my $mergeFile = "$dataFile.merge";
  my ($dataFh, $mergeFh);
  my $importCsv = Text::CSV->new( { binary => 1, sep_char => $sep } )
      or die "Couldn't use Text::CSV: " . Text::CSV->error_diag();
  my $dataCsv = Text::CSV->new( { binary => 1, sep_char => $sep } )
      or die "Couldn't use Text::CSV: " . Text::CSV->error_diag();
  my $mergeCsv = Text::CSV->new( { binary => 1, sep_char => $sep, eol => "\n" } )
    or die "Couldn't use Text::CSV: " . Text::CSV->error_diag();

  if (!-e $dataFile) {
    # write an empty file
    open $dataFh, ">$dataFile" or die "Couldn't open $dataFile for writing: $!";
    $dataCsv->print($dataFh, \@headers);
    close $dataFh or die "Couldn't close $dataFile: $!";
  }

  # read all the import data into a hash of arrays
  # assume there is a header, but don't assume the fields are in the same order always
  my %importData;
  open my $importFh, "<$importFile" or die "Couldn't open $importFile for reading: $!";
  $importCsv->column_names($importCsv->getline($importFh));
  while (my $row = $importCsv->getline_hr($importFh)) {
    $row->{KEY} = compositeKey($row->{STB}, $row->{TITLE}, $row->{DATE});
    # convert the hash to an array in the right order
    $importData{$row->{KEY}} = [];
    for my $header (@headers) {
      push @{$importData{$row->{KEY}}}, trim($row->{$header});
    }
  }
  close $importFh or die "Couldn't close $importFile: $!";

  open $mergeFh, ">$mergeFile" or die "Couldn't open $mergeFile for writing: $!";
  open $dataFh, "<$dataFile" or die "Couldn't open $dataFile for reading: $!";

  # for each line, if there is import data, write that to the merge file.
  # otherwise, write the src data to the merge file.
  my @headers = $dataCsv->getline($dataFh);
  $dataCsv->column_names(@headers);
  $mergeCsv->column_names(@headers);
  $mergeCsv->print($mergeFh, @headers);
  while (my $row = $dataCsv->getline($dataFh)) {
    my $mergeData;
    if ($importData{$row->[0]}) {
      $mergeCsv->print($mergeFh, $importData{$row->[0]});
      delete $importData{$row->[0]};
    }
    else {
      $mergeCsv->print($mergeFh, $row);
    }
  }
  close $dataFh or die "Couldn't close $dataFile: $!";

  # write the data from the import file that wasn't merged
  for my $data (values %importData) {
    $mergeCsv->print($mergeFh, $data);
  }
  close $mergeFh or die "Couldn't close $mergeFile: $!";

  # move the src file out of the way and make the dst file the data file
  rename $dataFile, "$dataFile.old" or die "Couldn't write the merged file, step 1: $!";
  rename $mergeFile, $dataFile or die "Couldn't write the merged file, step 2: $!";

  unlink "$dataFile.old" or warn "Couldn't delete old data file: $!";
}

sub query {
  my ($dataDir, $select, $filterKey, $filterVal, $order) = @_;

  my $dataFile = "$dataDir/$filename";
  my $dataFh;
  my $dataCsv = Text::CSV->new( { binary => 1, sep_char => $sep } )
      or die "Couldn't use Text::CSV: " . Text::CSV->error_diag();

  if (!-e $dataFile) {
    # return an empty list with no data
    return ();
  }

  # iterate through all rows in the CSV, adding rows to the output list as necessary
  # if there's no order clause, do everything in one pass, otherwise the
  # sort amounts to another pass through the data
  my @outputData;

  # read all the import data into a hash of arrays
  # assume there is a header, but don't assume the fields are in the same order always
  open $dataFh, "<$dataFile" or die "Couldn't open $dataFile for reading: $!";
  my @headers = $dataCsv->getline($dataFh);
  $dataCsv->column_names(@headers);
  while (my $row = $dataCsv->getline_hr($dataFh)) {
    #perform single column filtering
    next if $filterKey && !($row->{$filterKey} eq $filterVal);

    # perform column selection
    my @rowVals;
    for my $s (@$select) {
      push @rowVals, $row->{$s};
    }

    # create composite orderkey value
    if (scalar @$order > 0) {
      my @orderkey;
      for my $o (@$order) {
        push @orderkey, $row->{$o};
      }

      push @rowVals, join("|", @orderkey);
    }

    push @outputData, \@rowVals;
  }
  close $dataFh or die "Couldn't close $dataFh: $!";

  # sort if necessary, and delete the temp ORDERKEY column which is the last item in each rowVals
  if (scalar @$order && ($#outputData > 0)) {
    my $orderIndex = $#{$outputData[0]};
    @outputData = sort { $a->[$orderIndex] cmp $b->[$orderIndex] } @outputData;
    for my $row (@outputData) {
      pop @$row;
    }
  }

  return @outputData;
}
