package XML::SAXDriver::CSV;

use strict;
use vars qw($VERSION);

$VERSION = '0.03';

use Text::CSV_XS;

sub new {
    my ($class, %params) = @_;
    
    return bless \%params, $class;
}

sub parse {
    my $self = shift;

    my $args;
    if (@_ == 1 && !ref($_[0])) {
        $args = { Source => { String => shift }};
    }
    else {
        $args = (@_ == 1) ? shift : { @_ };
    }
    
    my $parse_options = { %$self, %$args };
    $self->{ParseOptions} = $parse_options;
    
    if (!defined($parse_options->{Source})
        || !(
            defined($parse_options->{Source}{String})
            || defined($parse_options->{Source}{ByteStream})
            || defined($parse_options->{Source}{SystemId})
            )) {
        die "XML::SAXDriver::CSV: no source defined for parse\n";
    }
    
    if (defined($parse_options->{Handler})) {
        $parse_options->{DocumentHandler} ||= $parse_options->{Handler};
        $parse_options->{DTDHandler} ||= $parse_options->{DTDHandler};
    }
    
    $parse_options->{NewLine} = "\n" unless defined($parse_options->{NewLine});
    $parse_options->{IndentChar} = "\t" unless defined($parse_options->{IndentChar});
        
    $parse_options->{Parser} ||= Text::CSV_XS->new();
    
    my ($ioref, @strings);
    if (defined($parse_options->{Source}{SystemId}) 
        || defined($parse_options->{Source}{ByteStream}) ) {
        $ioref = $parse_options->{Source}{ByteStream};
        if (!$ioref) {
            require IO::File;
            $ioref = IO::File->new($parse_options->{Source}{SystemId})
                    || die "Cannot open SystemId '$parse_options->{Source}{SystemId}' : $!";
        }
        
    }
    elsif (defined $parse_options->{Source}{String}) {
        @strings = split("\n", $parse_options->{Source}{String});
    }
    
    my $document = {};
    $parse_options->{Handler}->start_document($document);
    $parse_options->{Handler}->characters({Data => $parse_options->{NewLine}});
    
    my $doc_element = {
                Name => $parse_options->{File_Tag} || "records",
                Attributes => {},
            };

    $parse_options->{Handler}->start_element($doc_element);
    $parse_options->{Handler}->characters({Data => $parse_options->{NewLine}});
    

    $parse_options->{Col_Headings} ||= [];
    #my @col_headings = @{$parse_options->{Col_Headings}};
    
    $parse_options->{Headings_Handler} ||= \&normalize_heading;
             
    while (my $row = get_row($parse_options->{Parser}, $ioref, \@strings)) {
        my $el = {
            Name => $parse_options->{Parent_Tag} || "record",
            Attributes => {},
        };
        $parse_options->{Handler}->characters(
                {Data => $parse_options->{IndentChar}}
        );
        $parse_options->{Handler}->start_element($el);
        $parse_options->{Handler}->characters({Data => $parse_options->{NewLine}});
        
        
        if (!@{$parse_options->{Col_Headings}} && !$parse_options->{Dynamic_Col_Headings}) 
        {
                my $i = 1;
                @{$parse_options->{Col_Headings}} = map { "column" . $i++ } @$row;
        }
        elsif (!@{$parse_options->{Col_Headings}} && $parse_options->{Dynamic_Col_Headings})
        {
                @{$parse_options->{Col_Headings}} = map { $parse_options->{Headings_Handler}->($_, $parse_options->{SubChar}); } @$row; 
                next; # causes the first (heading) row to be skipped 
                            
        }   
    
        for (my $i = 0; $i <= $#{$row}; $i++) {
            my $column = { Name => $parse_options->{Col_Headings}->[$i], Attributes => {} };
            $parse_options->{Handler}->characters(
                    {Data => $parse_options->{IndentChar}} 
            );
            $parse_options->{Handler}->start_element($column);
            $parse_options->{Handler}->characters({Data => $row->[$i]});
            $parse_options->{Handler}->end_element($column);
            $parse_options->{Handler}->characters({Data => $parse_options->{NewLine}});
        }

        $parse_options->{Handler}->characters(
                {Data => $parse_options->{IndentChar}}
        );
        $parse_options->{Handler}->end_element($el);
        $parse_options->{Handler}->characters({Data => $parse_options->{NewLine}});
    }

    $parse_options->{Handler}->end_element($doc_element);
    
    return $parse_options->{Handler}->end_document($document);
}

sub normalize_heading  ### Default if no Headings_Handler is provided
{ 
  my $heading= shift;
  my $sub_char = shift || '_'; 
  $heading =~ s/^\s//g;
  $heading =~ s/\s$//g;
  $heading =~ s/^([^a-zA-Z|^_|^:])/$sub_char/g;   ### We used to also replace the xml in the beginning, but I took it of per recommendation of Michael Rodriguez.
  $heading =~ s/[^a-zA-Z|^-|^.|^0-9|^:]/$sub_char/g;
  return $heading; 
}

sub get_row {
    my ($parser, $ioref, $strings) = @_;
    
    if ($ioref) {
        my $line = <$ioref>;
        if ($line && $parser->parse($line)) {
            return [$parser->fields()];
        }
    }
    else {
        my $line = shift @$strings;
        if ($line && $parser->parse($line)) {
            return [$parser->fields()];
        }
    }
    return;
}

1;
__END__




=head1 NAME

    XML::SAXDriver::CSV - SAXDriver for converting CSV files to XML

=head1 SYNOPSIS

      use XML::SAXDriver::CSV;
      my $driver = XML::SAXDriver::CSV->new(%attr);
      $driver->parse(%attr);

=head1 DESCRIPTION

    XML::SAXDriver::CSV was developed as a complement to XML::CSV, though it provides a SAX
    interface, for gained performance and efficiency, to CSV files.  Specific object attributes
    and handlers are set to define the behavior of the parse() method.  It does not matter where 
    you define your attributes.  If they are defined in the new() method, they will apply to all
    parse() calls.  You can override in any call to parse() and it will remain local to that
    function call and not effect the rest of the object.

=head1 XML::SAXDriver::CSV properties

    Source - (Reference to a String, ByteStream, SystemId)
    
        String - Contains literal CSV data. Ex (Source => {String => $foo})
        
        ByteStream - Contains a filehandle reference.  Ex. (Source => {ByteStream => \*STDIN})
        
        SystemId - Contains the path to the file containing the CSV data. Ex (Source => {SystemId => '../csv/foo.csv'})
        
    Handler - Contains the object to be used as a XML print handler
    
    DTDHandler - Contains the object to be used as a XML DTD handler.  
                 ****There is no DTD support available at this time.  
                 I'll make it available in the next version.****
    
    NewLine - Specifies the new line character to be used for printing XML data (if any).
              Defaults to '\n' but can be changed.  If you don't want to indent use empty 
              quotes.  Ex. (NewLine => "")
              
    IndentChar - Specifies the indentation character to be used for printing XML data (if any).
                 Defaults to '\t' but can be changed.  Ex. (IndentChar => "\t\t")
                 
    SubChar - Specifies the character(s) to use to substitute illegal chars in xml tag names, that
              will be generated from the first row, but setting the Dynamic_Col_Headings.
                 
    Col_Headings - Reference to the array of column names to be used for XML tag names.
    
    Dynamic_Col_Headings - Should be set if you want the XML tag names generated dynamically
                           from the first row in CSV file.  **Make sure that the number of columns
                           in your first row is equal to the largest row in the document.  You
                           don't generally have to worry about if you are submitting valid CSV
                           data, where each row will have the same number of columns, even if
                           they are empty.
                           
    Headings_Handler - Should be used along with Dynamic_Col_Headings to provide a heading 
                         normalization handler, to conform the headings to the XML 1.0 
                         specifications.  If not provided, a default will be used that only
                         works with ASCII chars, therefore any other character sets need to 
                         provide a custom handler!  The handler sub will be passed the heading
                         string as the first argument.
                           
=head1 AUTHOR

Ilya Sterin (isterin@cpan.org)

Originally written by Matt Sergeant, matt@sergeant.org
Modified and maintained by Ilya Sterin, isterin@cpan.org

=head1 SEE ALSO

XML::CSV.

=cut
