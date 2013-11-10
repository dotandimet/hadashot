#!/usr/bin/env perl
use 5.016;
use Blackjack;
use Mojo::Util qw(encode);

sub test {
  my ($ua, $urls) = @_;
  my ($ok, $fail) = (0, 0);
  my $delay = Mojo::IOLoop->delay;
  $ua->max_redirects(5);
  for my $url (@$urls) {
    my $end = $delay->begin;
    $ua->get(
      $url => sub {
        my ($ua, $tx) = @_;
        $end->();
        if ($tx->success) {
          $ok++;
          say "Got ", $tx->res->code, " ",
            encode('UTF-8', $tx->res->dom->html->head->title->text);
        }
        else {
          my ($code, $err) = $tx->error;
          $fail++;
          say "Got error $err $code";
        }
      }
    );
  }
  $delay->wait;
  say "Tried ", scalar @$urls, " $ok succeeded, $fail failed\n";
}

my @urls;
while (my $line = <DATA>) {
  chomp($line);
  push @urls, $line if ($line =~ /^http/);
}

say "Got ", scalar @urls, " urls";
say $_ for (@urls);

say "Will fetch first 9:";
my @urls9 = @urls[0 .. 8];

#say "Fetching with Mojo::UserAgent";
#my $ua = Mojo::UserAgent->new;
#test($ua, \@urls9);

say "Now blackjack:";
my $ua = Blackjack->new;
test($ua, \@urls9);


say "Will fetch all ", scalar @urls;

 say "Fetching with Mojo::UserAgent";
 $ua = Mojo::UserAgent->new;
 test($ua, \@urls);
# 
say "Now blackjack:";
$ua = Blackjack->new;
test($ua, \@urls);

__DATA__
http://rcrowley.org/
http://www.notes.co.il/eshed
http://blog.forcharisma.com
http://www.scattershotgames.com
http://friendsofgeorge.blogli.co.il
http://www.indiepressrevolution.com/outofthebox
http://simonwillison.net/
http://memento-mori.com/wordpress
http://chainsawblues.vox.com/library/posts/page/1/
https://github.com/israellevin/afortiori/commits/master
http://calanya.livejournal.com/
http://blog.newint.org/tech/
http://badgods.com
http://romanticallyapocalyptic.com
http://www.primevalpress.com
http://www.sf-f.org.il/
http://seminarionit.blogli.co.il
http://www.havegameswilltravel.net
http://www.feartheboot.com/comic/rss.aspx
http://www.google.com/reader/view/feed%2Fhttp%3A%2F%2Ffuckyeahgamemasters.tumblr.com%2Frss
http://israblog.nana10.co.il/blogread.asp?blog=164873
http://www.zulo.org.il/blogs/
http://www.nizosblog.com/
http://www.d20radio.com
http://adigi.blogli.co.il
http://www.dilbert.com/
http://perlbuzz.com/
http://marcus.nordaaker.com
http://use.perl.org/~Ovid/journal/
http://www.xslf.com/
http://altneuland.lerner.co.il
http://perldition.org/
http://lumberjaph.net/
http://gesheft.blogli.co.il
http://glazkov.com
http://www.lumpley.com/

http://madsamrackham.livejournal.com/
http://ieuterpe.blogli.co.il
http://sartak.org
http://weblogs.mozillazine.org/roadmap/
http://proudtouseperl.com/
http://contemplating-from-gaza.blogspot.com/
http://langbeheim.livejournal.com/
http://blog.radvision.com/codeofcontact
http://www.justinachilli.com/blog/
http://shunit.blogli.co.il
http://www.tapuz.co.il/blog/userBlog.asp?Blogid=0
http://iods.blogli.co.il
http://www.rpg.net/reviews
http://shimshon.net
http://www.google.com/reader/view/feed%2Fhttp%3A%2F%2Fpbfcomics.com%2Ffeed%2Ffeed.xml
https://mozillalabs.com/
http://dorawrites.com/omg
http://www.mozillazine.org/
http://www.stephenfry.com
http://blogs.perl.org/users/erez_schatz/
http://www.bsisi.co.il
http://thevoiceoftherevolution.com
http://www.kcrw.org/
http://www.comictwart.com/
http://www.mitkaven.com
http://www.xirinet.com/
http://blog.woobling.org/
http://www.notes.co.il/gadi
http://www.sfnovelists.com
http://www.robmacdougall.org
http://warrocketajax.com
http://www.agreeablecomics.com/loneliestastronauts
http://www.spaaace.com/cope
http://rdonoghue.blogspot.com/
http://www.thesecretknots.com
/blog/
http://www.smodcast.com
http://www.aleph.se/andart/
http://rob-donoghue.livejournal.com/
http://plasmasturm.org/
http://realistcomics.blogspot.com/
http://www.damninteresting.com
http://blogs.perl.org/users/sawyer_x/
http://www.hahem.co.il/friendsofgeorge
http://www.sff.net/odyssey/podcasts.html
http://floggingbabel.blogspot.com/
http://www.rifters.com/crawl
http://endlessorigami.blogspot.com/
http://blog.xkcd.com
http://perltraining.com.au/tips/
http://ttapress.com/fix
https://brendaneich.com
http://williamgibsonblog.blogspot.com/
http://petdance.com
http://geshemm.livejournal.com/
http://ln.hixie.ch/
http://alienrights.blogspot.com/
http://canimal.blogspot.com/
http://www.awesomehospital.com
http://www.nyfiction.org
http://www.20by20room.com/
http://chapmanb.posterous.com
http://thegamesthething.com
http://iod.livejournal.com/
http://hatchling.blogspot.com/
http://thrillbent.com
http://www.orbitbooks.net
http://www.to-done.com
http://clown-alley.blogspot.com/
http://wordstudio.net/thegist
http://rifters.com/real/crawl.htm
http://steelight.livejournal.com/
http://blog.woobling.org/
http://lostintel-aviv.blogspot.com/
http://diveintomark.org/
http://gugod.org
http://plindenbaum.blogspot.com/
http://rss.warnerbros.com/watchmen/
http://blog.mozilla.org/faaborg
http://www.google.com/reader/view/feed%2Fhttp%3A%2F%2Fisrablog.nana.co.il%2Fblog_rss.asp%3Fblog%3D244696
http://onceinoticed.wordpress.com
http://craphound.com
http://www.haaretz.co.il/hasite/pages/tags
http://leonerds-code.blogspot.com/
http://damienlearnsperl.blogspot.com/
http://lisagoldman.net
http://gameplaywright.net
http://hapinkas.com
http://news.open-bio.org/news
http://blog.jquery.com
http://craphound.com
http://digitali.st
http://www.deepgenre.com/wordpress
http://godzillagamingpodcast.libsyn.com
http://www.tntforthebrain.com
http://ambientehotel.wordpress.com
http://bibliomancer.com
http://bulknews.typepad.com/blog/
http://www.hahem.co.il/trueandshocking
http://www.randsinrepose.com/
http://www.locusmag.com/Roundtable/
http://techblog.net-a-porter.com
http://openwebpodcast.com
http://blogs.discovermagazine.com/loom
http://www.ursulium.com
http://unlikelyworlds.blogspot.com/
http://www.vsca.ca/halfjack
http://www.zivkitaro.name
http://sflanguage.wordpress.com
http://2d6feet.com
http://www.ogrecave.com/audio
http://blog.kraih.com/
http://ygurvitz.livejournal.com/
http://www.jwz.org/blog/
http://www.stubbornella.org/content
http://www.blipanika.co.il
http://www.bazekalim.com
http://blogs.perl.org/users/su-shee/
http://uzwi.wordpress.com
http://techij.livejournal.com/
http://gaal.livejournal.com/
http://bits.strawjackal.org
http://sam.tregar.com/blog
http://onceinoticed.typepad.com/oin/
http://goleshet.blogli.co.il
http://blog.timbunce.org
http://www.ursulium.com/
http://blog.sukria.net
http://sonsofkryos.livejournal.com/
http://www.thecollective.co.il
http://theinferior4.livejournal.com/
http://thememorypalace.us
http://matthewrossi.wordpress.com
http://www.robertjschwalb.com
http://perlalchemy.blogspot.com/
http://www.arcanetimes.com/
http://labs.kraih.com/blog/
http://corky.net/dotan
http://www.warrenellis.com
http://owlbear-review.blogspot.com/
http://blog.fantasyheartbreaker.com
http://justatheory.com
http://oreilly.com/perl/
http://blog.strawjackal.org
http://internet.blogli.co.il
http://www.adigi.co.il/blog
http://www.simplicidade.org/notes/
http://www.smbc-comics.com
http://idlewords.com
http://blog.plover.com/
http://www.sintitulocomic.com
http://www.agreeablecomics.com/kimimura
http://mark.stosberg.com/blog/
http://www.snipe.net/
http://www.the-isb.com/
http://www.newscientist.com/
http://infectzia.net/ieuterpe
http://infrequently.org/
http://www.andrewrilstone.com/
http://acidcycles.wordpress.com
http://wickedthought.livejournal.com/
http://markpasc.typepad.com/blog/
http://worldsf.wordpress.com
http://www.learningjquery.com
http://blog.afoolishmanifesto.com
http://www.dagolden.com
http://www.mocktopus.com/
http://friendfeed.com/thenewfrontiersman
http://ira.abramov.org/blog
http://ezrael.livejournal.com/
http://www.effectiveperlprogramming.com
http://rjbs.manxome.org/rubric
http://joshbrown.livejournal.com/
http://cursedimagination.blogspot.com/
http://www.bbc.co.uk/programmes/b00lvdrj
http://www.ifyourejustjoiningus.com
http://www.playintheory.com
http://heidihalevi.wordpress.com
http://www.bbc.co.uk/programmes/b0070ltf
http://kidscomicbooks.blogspot.com/
http://corky.net/dotan
http://www.hilarymason.com
http://ochelogia.blogspot.com/
http://www.google.com/reader/view/feed%2Fhttp%3A%2F%2Fwww.kiwisbybeat.com%2Fkiwifeed.xml
http://sartak.org
http://blogs.perl.org/users/steven_haryanto/
http://blog.urth.org
http://hucksblog.blogspot.com/
http://shiffer.livejournal.com/
http://wrongquestions.blogspot.com/
http://princeofcairo.livejournal.com/
http://users.livejournal.com/yggdrasil_/
http://shadow.cat/blog/matt-s-trout/
http://minodudd.livejournal.com/
http://ijon.livejournal.com/
http://showmetheco.de/index.rss
http://24ways.org/
http://tnok.livejournal.com/
http://arcfinity.tumblr.com/
http://www.miketheman.net
http://sydneypadua.com/2dgoggles
http://ejohn.org
http://bartoszmilewski.com
http://belvane.livejournal.com/
http://blog.pokarov.com
http://dubikan.com
http://lukkke.livejournal.com/
http://oglaf.com/latest/
http://szabgab.com
http://howtonode.org
http://eyebeams.livejournal.com/
http://www.sjgames.com/ill/
http://heteromeles.wordpress.com
http://elliotlovesperl.com
http://google-opensource.blogspot.com/search/label/podcast
http://masterplanpodcast.net/
http://nsaunders.wordpress.com
http://www.letsbefriendsagain.com
http://beyondthegolem.wordpress.com
http://xkcd.com/
http://drupal.corky.net/frontpage
http://www.extremetech.com
http://lifehacker.com
http://gryphonk.livejournal.com/
http://corky.net/dotan
http://www.giborim.co.il
http://avgboojie.livejournal.com/
http://pythonwise.blogspot.com/
http://www.themoth.org/
http://www.antipope.org/charlie/blog-static/
http://escapepod.org
http://thatshowweroll.libsyn.com
http://bldgblog.blogspot.com/
http://passacaglio.livejournal.com/
http://boazrimmer.com
http://steve-yegge.blogspot.com/
http://www.guardian.co.uk/science/series/science/podcast.xml
http://blog.bolinfest.com/
http://tryscer.livejournal.com/
http://www.darthsanddroids.net/
http://kfmonkey.blogspot.com/
http://onionstand.blogspot.com/
http://www.beneath-ceaseless-skies.com
http://pulphope.blogspot.com/
http://www.thefreerpgblog.com/
http://www.icast.co.il/default.aspx?p=podcast&ID=50618
http://media.ajaxian.com/
http://www.timemachinego.com/linkmachinego
http://www.webcomicsnation.com/rscarbonneau/parsons/
http://www.popup.co.il
http://robin-d-laws.blogspot.com/
http://dndwithpornstars.blogspot.com/
http://sevatividam.blogspot.com/
http://fromgaza.blogspot.com/
http://blogs.perl.org/users/rurban/
http://www.freakangels.com
http://thisWEEKinTECH.com
http://disraeli-demon.blogspot.com/
http://www.writingexcuses.com
http://www.drabblecast.org
http://cafe.themarker.com/blog/147394/
http://filmspotting.net
http://sostuff.blogspot.com/

