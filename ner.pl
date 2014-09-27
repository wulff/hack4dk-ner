#!/usr/bin/env perl

# Stopord fra http://snowball.tartarus.org/algorithms/danish/stop.txt
# Fornavne fra http://www.familiestyrelsen.dk/soeginavnelister/godkendtefornavne/advanced/
# Efternavne fra http://finnholbek.dk/genealogy/surnames-all.php?tree=
# Stednavne: http://www.stednavneudvalget.ku.dk/autoriserede_stednavne/

use Modern::Perl;
use JSON;

binmode(STDOUT, ':utf8');

my $data = shift @ARGV;
die($data);

open my $stopwords, '<', 'stopwords.txt' or die "$!";
my @stopwords;
while (<$stopwords>) {
  chomp;
  push @stopwords, $_;
}
close $stopwords;

open my $names, '<', 'names.txt' or die "$!";
my @names;
while (<$names>) {
  chomp;
  push @names, $_;
}
close $names;

my @initwords = ('bin', 'de', 'du', 'van', 'der', 'von', 'mc', 'mac', 'le', 'for');

my %stopwords = map { $_ => 1 } @stopwords;
my %names     = map { $_ => 1 } @names;
my %initwords = map { $_ => 1 } @initwords;

{
  local $/ = undef;
  open my $fh, '<', $file or die "$!";
  $json = <$fh>;
  close $fh;
}

foreach my $record (@{$graph->{data}}) {
  my $ner = {};

  my $message = $record->{message};
  $message =~ s/\\u([[:xdigit:]]{1,4})/chr(eval("0x$1"))/egis;

  next unless $message;

  say $message;

  my @tokens = split /[\s\?\.,\"'«»\!\(\)\\]/, $message;
  @tokens = grep { $_ ne '' } @tokens;

  my @entity;
  for (my $i = 0; $i <= $#tokens; $i++) {
    my @entity = ();
    my $token = $tokens[$i];

    if ((lc($token) ne $token || $token =~ /^\d{4}$/ ) && !exists($stopwords{lc($token)}) && !exists($initwords{lc($token)})) {
      push @entity, $token;

      if (exists($tokens[$i + 1])) {
        my $token = $tokens[$i + 1];
        while ((lc($token) ne $token || exists($initwords{lc($token)}) || $token =~ /^\d{1,3}$/ ) && !exists($stopwords{lc($token)})) {
          $i++;
          push @entity, $token;
          last unless $tokens[$i + 1];
          $token = $tokens[$i + 1];
        }
      }

      SWITCH: {
        $entity[0] =~ /^\d{4}$/                   && do { push @{$ner->{years}}, $entity[0]; last SWITCH; };
        $entity[0] =~ /^\w+:/                     && do { push @{$ner->{bylines}}, "@entity"; last SWITCH; };
        "@entity"  =~ /[a-z]\s+\d+$/              && do { push @{$ner->{addresses}}, "@entity"; last SWITCH; };
        $entity[0] =~ /gade$|vej$|pladsen$|torv$/ && do { push @{$ner->{addresses}}, "@entity"; last SWITCH; };
        exists($names{$entity[0]})                && do { push @{$ner->{names}}, "@entity"; last SWITCH; };
        1                                         && do { push @{$ner->{tags}}, "@entity"; last SWITCH; };
      }
    }
  }

  print encode_json($ner);
  
  last;
}