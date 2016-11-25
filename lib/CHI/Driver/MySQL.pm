package CHI::Driver::MySQL;
use Mojo::Base 'CHI::Driver';

our $VERSION = '1.0';

use Encode qw(encode);
use Mojo::mysql;

has 'namespace';

has 'dsn' => sub {
    return shift->constructor_params->{ dsn };
};

has 'mysql' => sub {
    my $self = shift;

    my $mysql = Mojo::mysql->new( $self->dsn );
    
    $mysql->max_connections(1);
    $mysql->migrations->name('chi_cache')->from_data;

    $mysql->once(connection => sub { shift->migrations->migrate });

    return $mysql;
};

sub clear {
    my $self = shift;

    my $sql = 'delete from `chi_cache` where `namespace` = ?';
    $self->mysql->db->query($sql, $self->namespace);

    return 1;
}

sub fetch {
    my ( $self, $key ) = @_;

    my $sql = 'select `value` from `chi_cache` where `namespace` = ? and `key` = ?';
    my $result = $self->mysql->db->query($sql, $self->namespace, $key)
        ->hash;

    return $result && $result->{ value };
}

sub get_keys {
    my $self = shift;

    my $sql = 'select `key` from `chi_cache` where `namespace` = ?';
    my $keys = $self->mysql->db->query($sql, $self->namespace)
        ->arrays->map(sub { $_->[0] })->to_array;

    return @$keys;
}

sub get_namespaces {
    my $self = shift;

    my $sql = 'select distinct(`namespace`) from `chi_cache`';
    my $namespaces = $self->mysql->db->query($sql)
        ->arrays->map(sub { $_->[0] })->to_array;

    return @$namespaces;
}

sub remove {
    my ( $self, $key ) = @_;

    my $sql = 'delete from `chi_cache` where `namespace` = ? and `key` = ?';
    $self->mysql->db->query($sql, $self->namespace, $key);

    return 1;
}

sub store {
    my ( $self, $key, $data ) = @_;

    if ( $self->get($key) ) {
        my $sql = 'update `chi_cache` set `value` = ?, `updated_at` = now() where `namespace` = ? and `key` = ?';
        $self->mysql->db->query($sql, encode('UTF-8', $data), $self->namespace, $key);
    } else {
        my $sql = 'insert into `chi_cache` (`namespace`, `key`, `value`, `created_at`) values (?, ?, ?, now())';
        $self->mysql->db->query($sql, $self->namespace, $key, encode('UTF-8', $data));
    }

    return 1;
}

1;

__END__

=pod

=head1 NAME

CHI::Driver::MySQL - Use MySQL for cache storage

=head1 VERSION

version 1.0

=head1 SYNOPSIS

    use CHI;
    
    # Supply Data Source Name, defaults to C<dbi:mysql:dbname=test>.
    #
    my $cache = CHI->new( driver => 'MySQL', dsn => 'mysql://user:password@host:port/database' );

=head1 DESCRIPTION

This driver uses a `chi_cache` table to store the cache. The table is created by the driver itself.

Encode is required for encoding as UTF-8 the value that is about to be stored in database
Mojo::mysql is required for connection to database

=head1 AUTHOR

Adrian Crisan, E<lt>adrian.crisan88@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2016 by Adrian Crisan.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

__DATA__

@@ chi_cache
-- 1 up
create table if not exists `chi_cache` (
    `id`            int(11) NOT NULL AUTO_INCREMENT,
    `namespace`     VARCHAR( 255 ) not null,
    `key`           VARCHAR( 255 ) not null,
    `value`         LONGTEXT default null,
    `created_at`    datetime not null,
    `updated_at`    datetime default null,

    PRIMARY KEY (`id`)
);

-- 1 down
drop table if exists `chi_cache`;

-- 2 up
create index cache_namespace_key_idx on `chi_cache` (`namespace`(15), `key`(150));
