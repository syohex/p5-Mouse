package builder::MyBuilder;
use strict;
use warnings;
use utf8;
use 5.008_001;
use base qw(Module::Build::XSUtil);

sub new {
    my ($class, %args) = @_;

    $class->SUPER::new(
        %args,
        conflicts => {
            'Any::Moose',               '< 0.10',
            'MouseX::AttributeHelpers', '< 0.06',
            'MouseX::NativeTraits',     '< 1.00',
        },
        generate_ppport_h => 'ppport.h',
        generate_xshelper_h => 'xshelper.h',
        xs_files => {
            'xs-src/Mouse.xs' => 'lib/Mouse.xs',
        },
        c_source => [
            qw(
                xs-src/MouseAccessor.c
                xs-src/MouseAttribute.c
                xs-src/MouseTypeConstraints.c
                xs-src/MouseUtil.c
            )
        ],
        include_dirs => ['.'],
    );
}

sub ACTION_code {
    my ($class) = @_;

    system($^X, 'tool/generate-mouse-tiny.pl', 'lib/Mouse/Tiny.pm') == 0
        or warn "Cannot generate Mouse::Tiny: $!";

    unless ($class->pureperl_only) {
        require ExtUtils::ParseXS;
        for my $xs (qw(
            xs-src/MouseAccessor.xs
            xs-src/MouseAttribute.xs
            xs-src/MouseTypeConstraints.xs
            xs-src/MouseUtil.xs
        )) {
            (my $c = $xs) =~ s/\.xs\z/.c/;
            print "$xs => $c\n";
            ExtUtils::ParseXS::process_file(
                filename => $xs,
                output   => $c,
            );
        }
    }

    $class->SUPER::ACTION_code();
}

sub ACTION_test {
    my ($class) = @_;

    if ($ENV{COMPAT_TEST}) {
        $class->depends_on('moose_compat_test');
    }

    if ($class->pureperl_only) {
        print "pureperl only tests.\n";
        $class->SUPER::ACTION_test();
    } else {
        {
            print "xs tests.\n";
            local $ENV{MOUSE_XS} = 1;
            $class->SUPER::ACTION_test();
        }

        {
            print "pp tests.\n";
            local $ENV{PERL_ONLY} = 1;
            $class->SUPER::ACTION_test();
        }
    }
}

sub ACTION_moose_compat_test {
    my $class = shift;

    $class->depends_on('code');

    system($^X, 'tool/create-moose-compatibility-tests.pl')
        == 0 or warn "tool/create-moose-compatibility-tests.pl: $!";
}

1;
