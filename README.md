# comScore Programming Challenge

This repository implements the comScore programming challenge as implemented by
me, Avi Tevet.

# Setup

This script needs the following modules:

* Text::CSV

To install them, run this command:

    cpan Text::CSV

The scripts use a CSV file as the data store, so the script will need permissions to write to the <root dir>/data directory.  This directory can be changed with the ``--datadir`` option in both the ``import`` and ``query`` scripts.

# Running

Import data using the ``import`` script.  Check out the built-in help using the --help option:

    import --help

To import a file, run the ``import`` script with the --file or -f option:

    import -f myfile.tsv

To query the imported data, use the ``query`` script.  Check out the built-in help using the --help option:

    query --help

Get all the data:

    query

Get a subset of one or more fields:

    query -s PROVIDER
    query -s TITLE,STB,PROVIDER,DATE

Order by one or more fields:

    query -o DATE
    query -o DATE,STB,PROVIDER

Filter by a single field:

    query -f STB=stb1
    query -f TITLE="the matrix"

Combine the options as you wish:

    query -s STB,PROVIDER,DATE -o DATE
    query -f STB=stb1 -o VIEW_TIME
    query -s PROVIDER,TITLE,STB,DATE -o STB,DATE -f REV=4.00

# CONTACT

I can be reached on [LinkedIn](http://www.linked.com/in/avitevet). 

# LICENSE

This code is provided under the MIT License - see the LICENSE file for details.
