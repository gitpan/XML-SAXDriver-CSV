use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'XML::SAXDriver::CSV',
    'VERSION_FROM' => 'CSV.pm', # finds $VERSION
    'PREREQ_PM' => { Spreadsheet::ParseExcel => 0.20 }
);
