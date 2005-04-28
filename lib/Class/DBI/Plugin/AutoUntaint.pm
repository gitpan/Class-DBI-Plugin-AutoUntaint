package Class::DBI::Plugin::AutoUntaint;
use Carp();

use warnings;
use strict;

=head1 NAME

Class::DBI::Plugin::AutoUntaint - untaint columns automatically

=cut

our $VERSION = 0.03;

our %TypesMap = ( varchar   => 'printable',
                  char      => 'printable', # includes MySQL enum
                  blob      => 'printable', # includes MySQL text
                  integer   => 'integer',
                  bigint    => 'integer',
                  smallint  => 'integer',
                  date      => 'date',
                  );    

=head1 SYNOPSIS

    package Film;
    use Class::DBI::FromCGI;
    use Class::DBI::Plugin::Type;
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
                         date      => [ qw( birthday ) ],
                         }
                         
=item skip_columns

List of columns that will not be untainted:

    skip_columns => [ qw( secret_stuff internal_data ) ]

=item match_columns

Use regular expressions matching groups of columns to specify untaint 
types:

    match_columns => { qr(^(first|last)_name$) => 'printable',
                       qr(^.+_event$)          => 'date',
                       qr(^count_.+$)          => 'integer',
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

=item strict

If set to 1, will die if an untaint type cannot be determined for any column. 
Default is to issue warnings and not untaint these column(s).
    
=back

=back

=head2 Failures

The default mapping of column types to untaint types is set in C<%Class::DBI::Plugin::AutoUntaint::TypesMap>, and is probably incomplete. If you come across any failures, you can add suitable entries to the hash before calling C<auto_untaint()>. However, B<please> email the author with any failures so the hash 
can be updated for everyone.

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
    
    my %untaint;
    
    # $col->name preserves case - stringifying doesn't
    foreach my $col ( map { $_->name } $class->columns )
    {
        next if $skip{ $col };      
    
        my $type = $class->column_type( $col );
        
        die "No type detected for column $col ($class)" unless $type;

        my $ut = $ut_cols{ $col } || $ut_types->{ $type } || $TypesMap{ $type } || '';
                 
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
        
        my $fail = "No untaint type detected for column $col, type $type in $class"
            unless $ut;
            
        $fail and $args{strict} ? die $fail : warn $fail;
    
        my $type2 = substr( $type, 0, 25 );
        $type2 .= '...' unless $type2 eq $type;
        
        warn sprintf "Untainting %s %s [%s] as %s\n", 
            $class, $col, $type2, $ut 
            if $args{debug} > 1;
        
        push( @{ $untaint{ $ut } }, $col ) if $ut;
    }
    
    $class->untaint_columns( %untaint );    
}

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

=head1 COPYRIGHT & LICENSE

Copyright 2005 David Baird, All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Class::DBI::Plugin::AutoUntaint
