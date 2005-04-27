package Class::DBI::Plugin::AutoUntaint;

use warnings;
use strict;

=head1 NAME

Class::DBI::Plugin::AutoUntaint - untaint columns automatically

=cut

our $VERSION = '0.01';

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

    untaint_columns
    skip_columns
    match_columns
    untaint_types
    match_types
    
    debug    set to 1 for brief info, 2 for a list of each column's untaint type 
    
    maypole  set to 1 if this is a Maypole app (used by Maypole::Plugin::AutoUntaint)
    

=cut

sub auto_untaint 
{   # plugged-into class i.e. CDBI class
    my ( $class, %args ) = @_;
    
    warn "Untainting $class\n" if $args{debug} == 1;
    
    my $untaint_cols = $args{untaint_columns} || {}; # { $untaint_as => [qw( col1 col2 )], ... }
    my $skip_cols    = $args{skip_columns}    || [];
    my $match_cols   = $args{match_columns}   || {}; # { $col_regex  => $untaint_as, ... }
    my $ut_types     = $args{untaint_types}   || {}; # { $col_type   => $untaint_as, ... } 
    my $match_types  = $args{match_types}     || {}; # { $type_regex => $untaint_as, ... } 
    
    my %skip = map { $_ => 1 } @$skip_cols;
    
    my %ut_cols;
    
    foreach my $as ( keys %$untaint_cols )
    {
        $ut_cols{ $_ } = $as for @{ $untaint_cols->{ $as } };
    }
    
    # CDBI::mysql classes already provide _column_info(), but 
    # this might work elsewhere too (all taken from CDBI::mysql)
    $class->set_sql( desc_table => 'DESCRIBE __TABLE__' ) unless 
        $class->can( 'sql_desc_table' );
    ( my $sth = $class->sql_desc_table )->execute;
    my $column_info = { map { $_->{field} => $_ } $sth->fetchall_hash };
    #my $column_info = $class->_column_info;
    
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
        
        # die disappears if running within Maypole
        $type or $args{maypole} ? warn $msg : die $msg;
        
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
        
        # die disappears if running within Maypole
        my $msg2 = "No untaint type detected for column $col, type $type in $class" 
                    unless $ut;
        $ut or $args{maypole} ? warn $msg2 : die $msg2;
    
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
