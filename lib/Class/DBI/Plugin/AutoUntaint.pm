package Class::DBI::Plugin::AutoUntaint;

use warnings;
use strict;

=head1 NAME

Class::DBI::Plugin::AutoUntaint - untaint columns automatically

=cut

our $VERSION = 0.02;

=head1 SYNOPSIS

    package Film;
    use Class::DBI::FromCGI;
    use Class::DBI::Plugin::AutoUntaint;
    use base 'Class::DBI';
    # set up as any other Class::DBI class.
    
    # instead of this:
    #__PACKAGE__->untaint_columns(
    #    printable => [qw/Title Director/],
    #    integer   => [qw/DomesticGross NumExplodingSheep],
    #    date      => [qw/OpeningDate/],
    #    );
    
    # say this:
    __PACKAGE__->auto_untaint;
  
=head1 DESCRIPTION

Automatically detects suitable default untaint methods for most column types. 
Calls C<die> with an informative message for any columns it can't figure out. 
Accepts arguments for overriding the default untaint type. 

=head1 METHODS

=over 4 
  
=cut

sub import
{
    my ( $class ) = @_;
    
    my $caller = caller;
    
    no strict 'refs';   
    *{"$caller\::auto_untaint"} = \&auto_untaint;
}

=item auto_untaint( [ %args ] )

The following options can be set in C<%args>:

=over 4

=item untaint_columns

Specify untaint types for specific columns:

    untaint_columns => { printable => [ qw( name title ) ],
                         date => [ qw( birthday ) ],
                         }
                         
=item skip_columns

List of columns that will not be untainted:

    skip_columns => [ qw( secret_stuff internal_data ) ]

=item match_columns

Use regular expressions matching groups of columns to specify untaint 
types:

    match_columns => { qr(^(first|last)_name$) => 'printable',
                       qr(^.+_event$) => 'date',
                       qr(^count_.+$) => 'integer',
                       }
                       
=item untaint_types

Untaint according to SQL data types:

    untaint_types => { enum => 'printable',
                       }
                       
Defaults are taken from C<Class::DBI::FromCGI::column_type_for()>, but things 
like C<enum> don't have a universal default but might have a sensible default 
in a particular application. 
                        
=item match_types

Use a regular expression to map SQL data types to untaint types:

    match_types => { qr(^.*int$) => 'integer',
                     }
                     
=item debug
    
Control how much detail to report (via C<warn>) during setup. Set to 1 for brief 
info, and 2 for a list of each column's untaint type.
    
=back

=cut

sub auto_untaint 
{   # plugged-into class i.e. CDBI class
    my ( $class, %args ) = @_;
    
    warn "Untainting $class\n" if $args{debug} == 1;
    
    my $untaint_cols = $args{untaint_columns} || {}; 
    my $skip_cols    = $args{skip_columns}    || [];
    my $match_cols   = $args{match_columns}   || {}; 
    my $ut_types     = $args{untaint_types}   || {}; 
    my $match_types  = $args{match_types}     || {}; 
    
    my %skip = map { $_ => 1 } @$skip_cols;
    
    my %ut_cols;
    
    foreach my $as ( keys %$untaint_cols )
    {
        $ut_cols{ $_ } = $as for @{ $untaint_cols->{ $as } };
    }
    
    # CDBI::mysql classes already provide _column_info(), but 
    # this might work elsewhere too (all taken from CDBI::mysql)
    #my $column_info = $class->_column_info;
    $class->set_sql( desc_table => 'DESCRIBE __TABLE__' ) unless 
        $class->can( 'sql_desc_table' );
    ( my $sth = $class->sql_desc_table )->execute;
    my $column_info = { map { $_->{field} => $_ } $sth->fetchall_hash };
    
    # the above code is an attempt to make this work elsewhere than MySQL, but 
    # if it fails, let me know your db and any suggestions for fixing it
    $class->_croak( "Can't retrieve column_info for this db driver - please email author" )
        unless $column_info;
        
    my %untaint;
    
    # $col->name preserves case - stringifying doesn't
    foreach my $col ( map { $_->name } $class->columns )
    {
        next if $skip{ $col };      
    
        my $type = $column_info->{$col}->{type};
        
        my $msg = "No type detected for column $col ($class)" unless $type;

        # maybe other dbs return column_info in a different structure        
        if ( $args{debug} > 2 and $msg )
        {
            my $y = YAML->require;
            warn "Need YAML for extra debug info" unless $y;
            $msg .= "\n" . YAML::Dump( $column_info ) if $y;
        }
        
        die $msg unless $type;
        
        my $ut = $ut_cols{ $col } || $ut_types->{ $type } ||
                 Class::DBI::FromCGI::column_type_for( $type ) || '';
                 
        foreach my $regex ( keys %$match_types )
        {
            last if $ut;
            $ut = $match_types->{ $regex } if $type =~ $regex;
        }
        
        foreach my $regex ( keys %$match_cols )
        {
            last if $ut;
            $ut = $match_cols->{ $regex } if $col =~ $regex;
        }
        
        die "No untaint type detected for column $col, type $type in $class" unless $ut;
    
        my $type2 = substr( $type, 0, 25 );
        $type2 .= '...' unless $type2 eq $type;
        
        warn sprintf "Untainting %s %s [%s] as %s\n", 
            $class, $col, $type2, $ut 
            if $args{debug} > 1;
        
        push @{ $untaint{ $ut } }, $col;
    }
    
    $class->untaint_columns( %untaint );    
}


=back

=head1 TODO

Tests!

=head1 SEE ALSO

L<Class::DBI::FromCGI|Class::DBI::FromCGI>.

=head1 AUTHOR

David Baird, C<< <cpan@riverside-cms.co.uk> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-class-dbi-plugin-autountaint@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Class-DBI-Plugin-AutoUntaint>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2005 David Baird, All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Class::DBI::Plugin::AutoUntaint
