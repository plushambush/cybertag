#!/usr/bin/perl
#
# tag - a script which sets, modifies and inspect tags on the system.
# Copyright (C) 2012  Ivan Konov
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#            
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#                            
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
use File::Spec::Unix;
use Getopt::Long qw(:config prefix=--);
use Pod::Usage;

my $version='1.0b';
my $dir='tags.d';
my $dirmask=0755;
my $filemask=022;
$tagre=qr/^(-|\+)?((\w+):)?(\w+)$/;

my @settags;
my @matchtags;
my @listtags;

my $opt_list;
my $opt_exec;
my $opt_verbose;
my $opt_help;
my $opt_match;
my $opt_set;

$ret_success=0;
$ret_error=255;
$ret_match=0;
$ret_nomatch=1;


# main
$result=GetOptions(
   "set=s{,}"=> 	\@settags,
   "match=s{,}"=> 	\@matchtags,
   "dir=s"=> 		\$dir,
   "list:s"=> 		\@listtags,
   "exec=s"=> 		\$opt_exec,
   "verbose"=> 		\$opt_verbose,
   "help|?"=> 		\$opt_help,
   "version"=> 		\$opt_version,
   );

if (!$result) {
 pod2usage('-verbose'=>1,'-exitval'=>$ret_error);
}

$dir=File::Spec::Unix->canonpath($dir); 
 
if (@matchtags) { $opt_match=1 }
if (@settags) { $opt_set=1 }
if (@listtags) { $opt_list=1 }

if (@ARGV) {
  $opt_match=1;
  @matchtags=expand_tags(@ARGV);
}

if (($opt_set+$opt_match+$opt_list+$opt_help,$opt_version)>1) {
  die "Tag error: set,match,list,help,version commands cannot be mixed\n";
}
if ($opt_set) {
  command_set_tags(@settags);
  exit $ret_success;
}
if ($opt_list) {
  command_list_tags(@listtags);
  exit $ret_success;
}
if ($opt_match) {
  @matchtags=expand_tags(@matchtags);
  $m=command_match_tags(@matchtags);
  if ($opt_verbose) {  print "Match ", ($m) ? "successful" : "unsuccessful" , "\n"; }
  if ($m && $opt_exec) {
   if ($opt_verbose) { print "Executing ",  $opt_exec, "\n"}
   exit system $opt_exec;
  }
  else {
   if ($m) {exit $ret_match}
   else {exit $ret_nomatch}
  }
}
if ($opt_help) {
  pod2usage('-verbose'=>2,'-exitval'=>$ret_success);
}
if ($opt_version) {
  print "Version $version\n";
  exit $ret_success;
}

exit $ret_success;


sub command_set_tags {
my @tags;

 if ($#_<0) { pod2usage('-msg'=>"Missing argument of the --set option",'-verbose'=>1, '-exitval'=>$ret_error) }
 @t=expand_tags(@_); 
 while ($arg=shift(@t)) {
  if ($arg =~ $tagre ) {
   push @tags,$arg
  }
  else { pod2usage('-msg'=>"Wrong argument of the --set option ($arg)",'-verbose'=>1, '-exitval'=>$ret_error) }
 }
 for $tag (@tags) {
   $tag =~ $tagre;
   if ($1 eq "-") {
    del_tag($3,$4,$dir);
   }
   else {
    add_tag($3,$4,$dir);
   }
  }
  exit $ret_success;
}

sub command_list_tags {
 my $domain=@_[0];
 if ($domain) {
  if ($domain !~ /^[\w\d]+$/) { pod2usage('-msg'=>"Wrong argument of the --list option ($domain)",'-verbose'=>1,'-exitval'=>$ret_error)}
 }
 else {
   if (@ARGV) {
    if ($#ARGV>0) {
     pod2usage('-msg'=>"Multiple domains listing is not supported by --list",'-verbose'=>1,'-exitval'=>$ret_error);
    }
    else {
     $domain=$ARGV[0];
    }
   }
 }
 if ($opt_verbose) {print "Listing tags in $dir" , $domain?" (domain:$domain)":"","\n"}; 
 list_tags($domain,$dir);
}

sub command_match_tags {
 if (!$_[0]) {  pod2usage('-msg'=>"Missing argument of the --match option",'-verbose'=>1,'-exitval'=>$ret_error) } 
 while ($arg=shift(@_)) {
  if ($arg =~ $tagre  ) {
   push @tags,$arg
  }
  else { pod2usage('-msg'=>"Wrong argument of the --match option ($arg)",'-verbose'=>1,'-exitval'=>$ret_error) }
 }
 my $match_result=1;
 for $tag (@tags) {
   $tag =~ $tagre ;
   if ($1 eq "-") {
    $match_result &= match_absence($3,$4,$dir);
   }
   else {
    $match_result &= match_presence($3,$4,$dir);
   }
 }
 return $match_result;
}


sub add_tag {
  my ($dom,$tag,$dir)=@_;
  my $dompath=dompath($dom,$dir);
  my $fullpath=tagpath($dom,$tag,$dir);;
  my $fulltag=fulltag($dom,$tag);

  checkdir($dir);   
  if (! -d $dompath) {
   mkdir $dompath, $dirmask or die "Cannot add domain $dompath $!, stopped";
   if ($opt_verbose) { print "Created domain $dom\n"}
  }
  umask $filemask;
  open (my $fh,">",$fullpath) or die "Cannot add tag $fulltag $!, stopped";
  close $fh;
  if ($opt_verbose) {print "Added tag $fulltag\n"}
}

sub del_tag {
  my ($dom,$tag,$dir)=@_;
  checkdir($dir);
  my $dompath=dompath($dom,$dir);
  my $fullpath=tagpath($dom,$tag,$dir);
  my $fulltag=fulltag($dom,$tag);
  if (-e $fullpath) {  
    unlink $fullpath or die "Cannot remove tag $fulltag $!, stopped";
    if ($opt_verbose) {print "Removed tag: $fulltag\n"}
  }
  else {
   if ($opt_verbose) {print "Tag $fulltag is not set, skipping\n"}
  }
}

sub list_tags {
 my ($dom,$dir)=@_;
 my $dompath=dompath($dom,$dir);
 if (opendir(my $dh,$dompath)) {
  while ($tag=readdir $dh) {
   if (-f File::Spec::Unix->catfile($dompath,$tag)) {print "$tag\n"}
  }
 }
}

sub match_presence {
 my ($dom,$tag,$dir)=@_;
 my $fulltag=fulltag($dom,$tag);
 my $tagpath=tagpath($dom,$tag,$dir);
 if (-f $tagpath) { 
  if ($opt_verbose) {print "Matched presence of $fulltag \n"}
  return 1;
 }
 else { 
  if ($opt_verbose) {print "Not matched presence of $fulltag \n"}
  return 0;
 }
}

sub match_absence {
 my ($dom,$tag,$dir)=@_;
 my $fulltag=fulltag($dom,$tag);
 my $tagpath=tagpath($dom,$tag,$dir);
 if (-f $tagpath) {  
  if ($opt_verbose) {print "Not matched absence of $fulltag \n"}
  return 0;
 }
 else { 
  if ($opt_verbose) {print "Matched absence of $fulltag \n"}
  return 1;
 }
}

sub checkdir {
my $dir=shift(@_);
  if (! -d $dir) {
    die "Tags dir $dir doesn't exist. Please create one, stopped"
  }
}

sub tagpath {
 my ($dom,$tag,$dir)=@_;
 return File::Spec::Unix->rel2abs(File::Spec::Unix->catfile(File::Spec::Unix->catdir($dir,$dom),$tag));
}

sub dompath {
 my ($dom,$dir)=@_; 
 return File::Spec::Unix->rel2abs(File::Spec::Unix->catdir($dir,$dom))
}

sub fulltag {
 my ($dom,$tag) = @_;
 if ($dom) {
  return "$dom:$tag"
 }
 else {
  return $tag;
 }
}

sub expand_tags {
 my @ret_args;
 
 for $arg (@_) {
   if ($arg =~ /[\s,]/) {
    my @manyargs=split /[\s*,]/, $arg;
    push @ret_args,@manyargs;
   }
   else {
    push @ret_args,$arg
   }
  }
  return @ret_args;
}


__END__
=head1 NAME

tag - a script which sets, modifies and inspect tags on the system.

=head1 SYNOPSIS

tag [--verbose] [--dir[=]<path>] --list[[=]<domain>] | --set[=]<tag>,<tag>...| [--match[=]]<tag> <tag>... [--exec[=]<command>S< >[<args>]] | --help | --version

=head1 OPTIONS

 --dir[=]<directory>		Change directory where tags are stored (default is /etc/tags.d).
 --exec[=]<command> [<args>]	Execute a command if match successful. 
 --help				Print this help message. 
 --list[[=][<domain>]		List tags in specific domain (if any) or tags without a domain.
 --match[=]<tags list> 		Match given tags with system tags. Exit status = 0 if all tags matched, exit status = 1 otherwise. 
 --set[=]<tags list>		Set/delete tags.
 --verbose			Turn on verbose messages.
 --version			Prints version.
 
 <tags list> is a <tag>,<tag>,<tag>... or <tag> <tag> <tag>...

 <tag> is [+|-][<domain>:]<identifier> where:

 <domain>	tag namespace (optional)
 <identifier>	tag name (alphanumeric)
 + 		(may be omitted) sets a tag (with --set) or matches presence of tag (with --match)
 -		removes a tag (with --set) or matches absence of tag (with --match)

=head1 EXAMPLES

B<tag --set +tag1,tag2>

        Sets tag1 and tag2 (note omitted '+' in tag2)

B<tag --set local:tag1 -tag2>
 
        Sets tag1 in 'local' namespace and clears tag2
 
B<tag --list>
 
        Lists tags
  
B<tag --list work>
 
        Lists tags in 'work' namespace
 
B<tag --match='tag2,-tag1'>
 
        Match presence of tag2 and absence of tag1

B<tag tag3 -tag4>
 
        Match presence of tag3 and absence of tag4 (shorter form)
 
B<tag tag5 tag6 --exec 'echo "tag5 and tag6 matched"'>
 
        Executes echo command if tag2 and tag6 present
 
B<tag tag7,-tag8 && echo "use shell's command lists">
 
        Executes echo command if tag7 presend and tag8 absent (shell compatible)
 
B<tag tag8 || tag tag10 && tag -tag11 && echo "and this too">

        Executes echo command if tag8 or tag10 present and tag11 absent
=cut

