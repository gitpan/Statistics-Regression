#line 1 "inc/Module/Install/Fetch.pm - /home/ivan/lib/perl5/site_perl/5.8.0/Module/Install/Fetch.pm"
# $File: //depot/cpan/Module-Install/lib/Module/Install/Fetch.pm $ $Author: autrijus $
# $Revision: #8 $ $Change: 1374 $ $DateTime: 2003/03/18 11:50:15 $ vim: expandtab shiftwidth=4

package Module::Install::Fetch;
use Module::Install::Base; @ISA = qw(Module::Install::Base);

$VERSION = '0.01';

sub get_file {
    my ($self, %args) = @_;
    my ($scheme, $host, $path, $file) = 
        $args{url} =~ m|^(\w+)://([^/]+)(.+)/(.+)| or return;

    if ($scheme eq 'http' and !eval { require LWP::Simple; 1 }) {
        $args{url} = $args{ftp_url}
            or (warn("LWP support unavailable!\n"), return);
        ($scheme, $host, $path, $file) = 
            $args{url} =~ m|^(\w+)://([^/]+)(.+)/(.+)| or return;
    }

    $|++;
    print "Fetching '$file' from $host... ";

    unless (eval { require Socket; Socket::inet_aton($host) }) {
        warn "'$host' resolve failed!\n";
        return;
    }

    return unless $scheme eq 'ftp' or $scheme eq 'http';

    require Cwd;
    my $dir = Cwd::getcwd();
    chdir $args{local_dir} or return if exists $args{local_dir};

    if (eval { require LWP::Simple; 1 }) {
        LWP::Simple::mirror($args{url}, $file);
    }
    elsif (eval { require Net::FTP; 1 }) { eval {
        # use Net::FTP to get past firewall
        my $ftp = Net::FTP->new($host, Passive => 1, Timeout => 600);
        $ftp->login("anonymous", 'anonymous@example.com');
        $ftp->cwd($path);
        $ftp->binary;
        $ftp->get($file) or (warn("$!\n"), return);
        $ftp->quit;
    } }
    elsif (my $ftp = $self->can_run('ftp')) { eval {
        # no Net::FTP, fallback to ftp.exe
        require FileHandle;
        my $fh = FileHandle->new;

        local $SIG{CHLD} = 'IGNORE';
        unless ($fh->open("|$ftp -n")) {
            warn "Couldn't open ftp: $!\n";
            chdir $dir; return;
        }

        my @dialog = split(/\n/, << ".");
open $host
user anonymous anonymous\@example.com
cd $path
binary
get $file $file
quit
.
        foreach (@dialog) { $fh->print("$_\n") }
        $fh->close;
    } }
    else {
        warn "No working 'ftp' program available!\n";
        chdir $dir; return;
    }

    unless (-f $file) {
        warn "Fetching failed: $@\n";
        chdir $dir; return;
    }

    return if exists $args{size} and -s $file != $args{size};
    system($args{run}) if exists $args{run};
    unlink($file) if $args{remove};

    print(((!exists $args{check_for} or -e $args{check_for})
        ? "done!" : "failed! ($!)"), "\n");
    chdir $dir; return !$?;
}

1;
