#!/usr/bin/env perl

# stop words from http://snowball.tartarus.org/algorithms/danish/stop.txt
# names from http://www.familiestyrelsen.dk/soeginavnelister/godkendtefornavne/advanced/
# surnames from http://finnholbek.dk/genealogy/surnames-all.php?tree=
# Stednavne: http://www.stednavneudvalget.ku.dk/autoriserede_stednavne/

use Modern::Perl;
use JSON;

# slurp data from stdin
my $message;
{
  local $/ = undef;
  $message = <STDIN>;
}

# make perl understand utf8 input
utf8::decode($message);

# initialize word lists
my @stopwords = get_wordlist('stopwords.txt');
my @names     = get_wordlist('names.txt');
my @initwords = get_initwords();

# convert word lists to hashes for easy lookup
my %stopwords = map { $_ => 1 } @stopwords;
my %names     = map { $_ => 1 } @names;
my %initwords = map { $_ => 1 } @initwords;

# init result hash
my $ner = {};

# tokenize input
my @tokens = split /[\s\?\.,\"'«»\!\(\)\\]/, $message;
@tokens = grep { $_ ne '' } @tokens;

# try to find named entities in the list of tokens
my @entity;
for (my $i = 0; $i <= $#tokens; $i++) {
  my @entity = ();
  my $token = $tokens[$i];

  # proceed if the token is uppercase or a year but NOT a stop word or initword
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

# return json-encoded data
print encode_json($ner);

# utility functions

sub get_wordlist {
  my $filename = shift;

  open my $fh, '<', $filename or die "Can't open $filename: $!";
  my @wordlist;
  while (<$fh>) {
    chomp;
    push @wordlist, $_;
  }
  close $fh;

  return @wordlist;
}

sub get_initwords {
  return ('bin', 'de', 'du', 'van', 'der', 'von', 'mc', 'mac', 'le', 'for');
}
