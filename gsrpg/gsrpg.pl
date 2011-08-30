#!/usr/local/bin/perl

# GSRPG1.2.1; an Idle RPG Bot
# Copyright (c) 2004-2009, Jake Ray, Nick Hale and the GSRPG Development Team
# All rights reserved.
# http://www.irpg.net

# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:

#  * Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
#  * Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#  * Neither the name of the GSRPG Developers nor the names of its contributors
#    may be used to endorse or promote products derived from this software
#    without specific prior written permission.

# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
# THE POSSIBILITY OF SUCH DAMAGE.

use DBI;
use strict;
use IO::Socket;
use Getopt::Long;

my $version = '1.2.1';
my $config = 'gsrpg.conf';          # default name of the config file

my $debug = 0;                      # so perl doesn't throw any errors at us
my $help = 0;
my $verbose = 0;

GetOptions(
    'debug|d' => \$debug,
    'verbose|v' => \$verbose,
    'help|h' => \$help,
    'configfile|f=s' => \$config);

my %options = loadconfig();         # array of options from the config file

my $alarmint = 5;                   # interval between when the bot checks the game; best left at 5
my %auto_login;                     # players that get logged automatically
my $bans = 0;                       # number of stored bans on the bot channel
my $chanrec = 0;                    # used in the logging of channel statistics
my $chantime = 0;                   # stores elapsed time between channel logs
my $conn_tries = 0;                 # how many times we've tried to connect to the server
my $curnick = $options{botnick};    # bot's current nick
my $db;                             # DBI database object
my $inbytes = 0;                    # bytes received by the bot
my $lastalarm = time();              # last time an alarm triggered
my $lastquit = 0;                   # last time the bot was disconnected
my $modespl = 6;                    # maximum number of modes per line the server supports
my %onchan;                         # list of people currently in the channel
my $outbytes = 0;                   # bytes sent out by the bot
my %prev_online;                    # users who were previously online
my $reconnect = 1;                  # set to zero if die is called; restarts the script
my $startup = time();               # when the bot started
my $timer = 0;                      # stores time elapsed between set intervals (usually 6h)
my $xnick;                          # +x fix for IRCu-based networks (maybe others)

my $quest = '';                     # name of the active quest
my $questcheck = 0;                 # stores time elapsed between quest reports
my @questers;                       # users currently on the quest
my $questtime = 0;                  # how long the quest lasts

$debug = $options{debug} if $debug != $options{debug};
$verbose = $options{verbose} if $verbose != $options{verbose};

$help and do { showhelp(); exit 0; };

daemonize();    # detach from the controlling terminal

print "Opening database connection...\n" if $verbose;
opendb();

CONNECT:
$conn_tries++;
print "Building socket to $options{server} [attempt #$conn_tries]\n" if $verbose;
my %build = (PeerAddr=>$options{server},
             PeerPort=>$options{port},
             Timeout=>7);
$build{LocalAddr} = $options{localaddr} if length($options{localaddr});
my $sock = IO::Socket::INET->new(%build);
undef %build;
alog("Could not build socket [attempt #$conn_tries]; $!",0) unless $sock;

if ($sock) {
    print "Connected to server, sending user info...\n" if $verbose;
    puttext("PASS $options{serverpass}") if $options{serverpass};
    puttext("NICK $options{botnick}");
    puttext("USER $options{username} localhost x :$options{realname}");
    alog("GSRPG successfully started.",0);
}

while (<$sock>) {
    $inbytes += length;
    s/[\r\n]//g;
    s/[[:cntrl:]]//g if $options{stripcodes};
    print "<- $_\n" if $debug;
    my @arg = split/ /;
    if (lc($arg[0]) eq 'ping') { puttext("PONG $arg[1]"); }
    elsif ($arg[1] eq '433' && $options{botnick} eq $arg[3] && $curnick ne $arg[2]) {
        $curnick .= 0;
        puttext("NICK $curnick");
    }
    elsif ($arg[1] eq '001') {
        print "Authenicated to the server, sending startup info...\n" if $verbose;
        my $query = $db->prepare("SELECT playerid,username ".
		"FROM gsrpg_players WHERE online = 1");
        $query->execute;
	if ($query->rows > 0) {
            %prev_online = ();
            while (my @player = $query->fetchrow_array) {
                $prev_online{$player[0]} = $player[1];
            }
            $query->finish;
        } 
        $db->do("UPDATE gsrpg_players SET lastlogout = $lastquit WHERE online = 1");
        $db->do("UPDATE gsrpg_players SET online = 0");
        puttext($options{authline}) if $options{authline};
        puttext("MODE $curnick $options{usermodes}");
        puttext("JOIN $options{botchan}");
        puttext("JOIN $options{monitorchan} $options{monitorchanpass}") if $options{monitor};
        puttext("WHO $options{botchan}");
        $options{botchan} =~ s/ .*//g;
        puttext("MODE $options{botchan}");
        alog("Connection to IRC server established.",0);
        $conn_tries = 0;
    }
    elsif ($arg[1] eq '005') { $modespl = $1 if /MODES=(\d{1,2})/; }
    elsif ($arg[1] eq '352' && lc($arg[3]) eq lc($options{botchan})) {
        $onchan{$arg[7]} = time();
        next() unless scalar keys %prev_online > 0;
        $arg[7] =~ s/\\/\\\\/g if $arg[7] =~ /\\/;
        my $fulladdress = $arg[7]."!".$arg[4]."\@".$arg[5];
        my @user = $db->selectrow_array("SELECT playerid,username FROM gsrpg_players ".
                                        "WHERE userhost = '$fulladdress' ORDER BY lastlogin DESC LIMIT 1");
        $auto_login{$user[0]} = $user[1] if @user && exists $prev_online{$user[0]};
    }
    elsif ($arg[1] eq '315' && lc($arg[3]) eq lc($options{botchan})) {
        if (%auto_login) {
            my $query = $db->prepare("UPDATE gsrpg_players SET online = 1, lastlogin = '".time()."',".
                                     "next=next+(".time()."-$lastquit), challenge=challenge+(".time().
                                     "-$lastquit), idled=idled+(".time()."-$lastquit) WHERE playerid=?")
                                     or die $db->errstr;
            my @auto_users = sort { "\L$a" cmp "\L$b" } values %auto_login; # unwind the hash
            foreach my $id (keys %auto_login) { $query->execute($id); }
            $query->finish;
            chanmsg("Found ".scalar @auto_users." users out of ".
                    fetchvalue("gsrpg_players","COUNT(online)","status","1")." registered players ".
                    "qualifying for autologin");
            chanmsg(join(", ",@auto_users));
            massmodes() if $options{giveops} || $options{givevoice};
            undef %auto_login; undef @auto_users; undef %prev_online;
            alog("Autologin complete.",0);
        }
        # if prev_online is null, the bot is rejoining the channel
        else { chanmsg("Found zero users qualifying for auto-login."); }
    }
    elsif ($arg[1] eq '322' && lc($arg[3]) eq lc($options{botchan})) { $chanrec = $arg[4]; }
    elsif ($arg[1] eq '367' && lc($arg[3]) eq lc($options{botchan})) { $bans++; }
    elsif ($arg[1] eq '368' && lc($arg[3]) eq lc($options{botchan})) {
        next() unless $chanrec > 0;
        open(C,">>$options{chanlog}");
        print C time().",$chanrec,$bans,".(time()-$startup).",$inbytes,$outbytes\n";
        close C;
    }
    elsif (lc($arg[1]) eq 'nick') {
        my $usernick = (split(/!/,$arg[0]))[0];
        $usernick = substr($usernick,1);
        my $escaped = $usernick;
        $escaped =~ s/\\/\\\\/g if $usernick =~ /\\/;
        if ($usernick eq $curnick) { $curnick = substr($arg[2],1); }
        my @player = fetcharray("gsrpg_players","playerid,next,level,online,userhost","nick",$escaped);
        if (@player && $player[3] eq '1') {
            my $pen = int(30 * ($options{penaltystep}**$player[2]));
            my $newnick = substr($arg[2],1);
            my $newescape = $newnick;
            $newescape =~ s/\\/\\\\/g;
            my $host = substr($arg[0],1+length($newnick));
            $db->do("UPDATE gsrpg_players SET nick = '$newescape', ".
                    "userhost = '".$newescape.$host."' WHERE playerid = '$player[0]'");
            penalize($player[0],'nick',$pen) if $options{pennick};
        }
        questcheck($player[0]);
        $onchan{substr($arg[2],1)} = delete $onchan{$usernick};   
    }
    elsif (lc($arg[1]) eq 'join') {
        $arg[2] =~ s/^://;      # bahamut fix
        next() unless lc($arg[2]) eq lc($options{botchan});
        my $usernick = (split(/!/,$arg[0]))[0];
        $usernick = substr($usernick,1);
        if ($usernick eq $curnick) {
            alog("Starting SIGALRM.",0);
            $SIG{ALRM} = \&rpcheck;
            alarm(5);  # do NOT decrease
            puttext($options{chanline}) if $options{chanline};
        }
        $onchan{$usernick} = time();
        if ($usernick eq $xnick) {
            my $escaped = $usernick;
            $escaped =~ s/\\/\\\\/g;
            my $host = substr($arg[0],1+length($usernick));
            $db->do("UPDATE gsrpg_players SET userhost = '".$escaped.$host."' WHERE nick = '$escaped'");
        }
    }
    elsif (lc($arg[1]) eq 'kick' && lc($arg[2]) eq lc($options{botchan})) {
        my $usernick = $arg[3];
        puttext("JOIN $options{botchan}") if $arg[3] eq $curnick;
        my $escaped = $usernick;
        $escaped =~ s/\\/\\\\/g;
        my @player = fetcharray("gsrpg_players","playerid,next,level,online","nick",$escaped);
        if ($player[3] eq '1') {
            my $pen = int(50 * ($options{penaltystep}**$player[2]));
            penalize($player[0],'kick',$pen) if $options{penkick};
            $db->do("UPDATE gsrpg_players SET online = 0, lastlogout = ".time().
                    " WHERE playerid = $player[0]");
            questcheck($player[0]);
        }
        delete $onchan{$usernick};
    }
    elsif (lc($arg[1]) eq 'part' && lc($arg[2]) eq lc($options{botchan})) {
        my $usernick = (split(/!/,$arg[0]))[0];
        $usernick = substr($usernick,1);
        my $escaped = $usernick;
        $escaped =~ s/\\/\\\\/g;
        my @player = fetcharray("gsrpg_players","playerid,next,level,online","nick",$escaped);
        if ($player[3] eq '1') {
            my $pen = int(200 * ($options{penaltystep}**$player[2]));
            penalize($player[0],'part',$pen) if $options{penpart};
            $db->do("UPDATE gsrpg_players SET online = 0, lastlogout = ".time().
                    " WHERE playerid = $player[0]");
            questcheck($player[0]);
        }
        delete $onchan{$usernick};
    }
    elsif (lc($arg[1]) eq 'quit' && $arg[2] eq ':Registered') {
        my $usernick = (split(/!/,$arg[0]))[0];
        $usernick = substr($usernick,1);
        if (exists $onchan{$usernick}) {
            my $escaped = $usernick;
            $escaped =~ s/\\/\\\\/g;
            my $player = fetchvalue("gsrpg_players","online","nick",$escaped);
            $xnick = $usernick if $player eq '1';
        }
    }
    elsif (lc($arg[1]) eq 'quit' && $options{tracksplits}
           && ("@arg[2..3]" eq ':*.net *.split'
               || "@arg[2..3]" =~ /^:\w*\.?\w+\.\w+ \w*\.?\w+\.\w+/)) {     # no penalty
        my $usernick = (split(/!/,$arg[0]))[0];
        $usernick = substr($usernick,1);
        if (exists $onchan{$usernick}) {
            my $escaped = $usernick;
            $escaped =~ s/\\/\\\\/g;
            my @player = fetcharray("gsrpg_players","playerid,next,level,online","nick",$escaped);
            $db->do("UPDATE gsrpg_players SET online = 0, lastlogout = ".time().
                    " WHERE playerid = $player[0]") if $player[3] eq '1';
            if ($#questers > 1 && length($quest) > 0) {     # cancel the quest
                undef @questers; $questtime = 0;
                $questtime = time();
            }
            delete $onchan{$usernick};   
        }
    }
    elsif (lc($arg[1]) eq 'quit' && $options{xregfix} && $arg[2] ne ':Registered') {
        my $usernick = (split(/!/,$arg[0]))[0];
        $usernick = substr($usernick,1);
        if (exists $onchan{$usernick}) {
            my $escaped = $usernick;
            $escaped =~ s/\\/\\\\/g;
            my @player = fetcharray("gsrpg_players","playerid,next,level,online","nick",$escaped);
            if ($player[3] eq '1') {
                my $pen = int(30 * ($options{penaltystep}**$player[2]));
                penalize($player[0],'quit',$pen) if $options{penquit};
                $db->do("UPDATE gsrpg_players SET online = 0, lastlogout = ".time().
                        " WHERE playerid = $player[0]");
                questcheck($player[0]);
            }
            delete $onchan{$usernick};
        }
    }
    elsif (lc($arg[1]) eq 'privmsg') {
        my $usernick = (split(/!/,$arg[0]))[0];
        $usernick = substr($usernick,1);
        next() if $usernick =~ /\\$/;                       # unresolved bug with trailing \'s in name
        my $escaped = $usernick;
        $escaped =~ s/\\/\\\\/g;       # nasty hack for PG
        $arg[3] = substr($arg[3],1);
        if (lc($arg[2]) eq lc($options{botnick})) {
            if (lc($arg[3]) eq "\1version\1") {
                privmsg("\1VERSION GSRPG [$version] by Jake; $options{helpurl}\1",$usernick,1); }
            elsif (lc($arg[3]) eq 'help') {
                privmsg("I am GSRPG$version, the Idle RPG bot",$usernick);
                privmsg("To register a new account: \2/msg $curnick REGISTER\2",$usernick);
                if (!$options{floodwatch}) {
                    privmsg("To login to an existing account: \2/msg $curnick LOGIN\2",$usernick);
                    privmsg("If you want to change your class name: \2/msg $curnick CLASS\2",$usernick);
                    privmsg("If you want to view your items: \2/msg $curnick ITEMS\2",$usernick);
                    privmsg("All this information and much more can be viewed at $options{helpurl}",$usernick);
                }
                privmsg("Admin Information: $options{adminurl}",$usernick) if adminlevel($usernick) > 0;
                next();
            }
            elsif (lc($arg[3]) eq 'register') {
                my @player = fetcharray("gsrpg_players","username,online","nick",$usernick);
                if ($player[1] eq '1') { privmsg("You are already logged in as $player[0].",$usernick); }
                else {
                    if (!exists $onchan{$usernick}) {
                        privmsg("You must be in $options{botchan} to register a player.",$usernick); }
                    elsif ($#arg < 7 || $arg[7] eq '') {
                        privmsg("Syntax of \2REGISTER\2: /msg $curnick REGISTER ".
                                "<username> <password> <emailaddress> <class name>",$usernick);
                        if (!$options{floodwatch}) {
                            privmsg("Username and password can whatever you like, up ".
                                    "to a maximum of 20 characters.",$usernick);
                            privmsg("Your email address will be used on the site and ".
                                    "for occasional announcements. (not spam!)",$usernick);
                            privmsg("Class name should be a short description of your player, ".
                                    "and should \2not\2 include \"the\" at the beginning.",$usernick);
                        }
                        privmsg("Example: /msg $curnick REGISTER Jake somepass ".
                                "foo\@bar.com Drunken College Student",$usernick);
                    }
                    elsif (length($arg[4]) > 20 || length($arg[5]) > 20) {
                        privmsg("Usernames and passwords should be no longer than 20 characters",$usernick); }
                    elsif ($arg[4] eq $arg[5]) {
                        privmsg("Your username and password should not be the same word.",$usernick); }
                    elsif ($arg[4] =~ /\W/) {
                        privmsg("Usernames should be alphanumeric (a-z,0-9).",$usernick); }
                    elsif (length($arg[6]) > 50) {
                        privmsg("You don't really have an email address that long, do you?",$usernick); }
                    elsif (length("@arg[7..$#arg]") > 50) {
                        privmsg("Class names should be no longer than 50 characters.",$usernick); }
                    elsif ($arg[6] !~ /[\w|-]+@[\w|-]+\.\w+/) {
                        privmsg("\"$arg[6]\" is an invalid email address.",$usernick); }
                    elsif ($arg[4] =~ /gsrpg/i) {
                        privmsg("Sorry, but your username cannot contain the word \"gsrpg\".",$usernick); }
                    elsif (fetchvalue("gsrpg_players","playerid","username",$arg[4]) ne '') {
                        privmsg("That username is already taken. Please choose another",$usernick); }
                    else {
                        my $class = "@arg[7..$#arg]";
                        $class =~ s/'/\\'/;
                        $db->do("INSERT INTO gsrpg_players (playerid,username,password,email,gameid,level,".
                                "class,online,idled,next,created,lastlogin,nick,userhost,noop,status,admin) ".
                                "VALUES (nextval('public.gsrpg_players_playerid_seq'::text),'$arg[4]','".
                                crypt($arg[5],mksalt())."','$arg[6]','1','0','$class','1','".time()."','".
                                (time()+$options{baselevel})."','".time()."','".time()."','$escaped','".
                                substr($arg[0],1)."','0','1','0')");
                        my $id = fetchvalue("gsrpg_players","playerid","username",$arg[4]);
                        $db->do("INSERT INTO gsrpg_items (playerid) VALUES ($id)");
                        $db->do("INSERT INTO gsrpg_penalties (playerid) VALUES ($id)");
                        $db->do("UPDATE gsrpg_players SET admin = 10 WHERE playerid = $id")
                            if $arg[4] eq $options{botadmin} && fetchvalue("gsrpg_players","SUM(admin)",
                            "online","1") == 0;  # grant admin access to botadmin
                        chanmsg("Welcome $usernick\'s new player $arg[4], the @arg[7..$#arg]! Next level ".
                                "in ".dur($options{baselevel}).".");
                        privmsg("Success! Your account has been created! You now have $options{baselevel} ".
                                "seconds of idling before your first level.",$usernick);
                        if (!$options{floodwatch}) {
                            privmsg("The point of the Idle RPG is to idle; as such, talking (in the channel ".
                                    "or to the bot, quitting, or leaving the channel will result in penalties ".
                                    "against you.",$usernick);
                            privmsg("As you progress, you will gain items, go on quests, and battle other players ".
                                    "in the game. These events can help you tremendously but also have the ".
                                    "potential to set you back a great deal.",$usernick);
                            privmsg("A complete record of everything that has happened to you, as well as a full ".
                                "list of commands is available at $options{helpurl}.",$usernick);
                        }
                    }
                }
            }
            elsif (lc($arg[3]) eq 'login') {
                if (!exists $onchan{$usernick}) {
                    privmsg("You must be in $options{botchan} to use this command.",$usernick); }
                elsif ($#arg < 5 || $arg[5] eq '') {
                    privmsg("Syntax of \2LOGIN\2: /msg $curnick LOGIN <username> <password>",$usernick);
                    privmsg("Example: /msg $curnick LOGIN Jake mypassword",$usernick);
                }
                elsif (!checkstr($arg[4])) { privmsg("\"$arg[4]\" is an invalid user name.",$usernick); }
                else {
                    my @player = fetcharray("gsrpg_players","username,online","nick",$escaped);
                    if ($player[1] eq '1') { privmsg("You are already logged in as $player[0].",$usernick); }
                    else {
                        my $host = substr($arg[0],1+length($usernick));
                        my $user = fetchvalue("gsrpg_players","password","username",$arg[4]);
                        if (!exists $onchan{$usernick}) {
                            privmsg("You must be in $options{botchan} to register a player",$usernick); }
                        elsif (!$user) {
                            privmsg("\"$arg[4]\" is an invalid username. Please correct any ".
                                    "misspellings and try again.",$usernick); }
                        elsif ($user ne crypt($arg[5],$user)) {
                            privmsg("You have entered an invalid password. Please try again.",$usernick); }
                        else {
                            my $online = fetchvalue("gsrpg_players","online","username",$arg[4]);
                            if ($online ne '1') {
                                $db->do("UPDATE gsrpg_players SET next=next+(".time()."-lastlogout),".
                                    "idled=idled+(".time()."-lastlogout), challenge=challenge+(".
                                    time()."-lastlogout), online = 1, nick = '${escaped}', userhost = '".
                                    $escaped.$host."', lastlogin = '".time()."' WHERE username = '$arg[4]'");
                            }
                            else {
                                $db->do("UPDATE gsrpg_players SET nick = '${escaped}', userhost = '".
                                    $escaped.$host."' WHERE username = '$arg[4]'");
                            }
                            chanmsg("$arg[4], the level ".fetchvalue("gsrpg_players","level","nick",$escaped).
                                    " ".fetchvalue("gsrpg_players","class","nick",$escaped)." is now online ".
                                    "from nickname $usernick. Next level in ".
                                    dur(fetchvalue("gsrpg_players","next","username",$arg[4])-time()).".");
                            privmsg("Successfully logged you in to account $arg[4]. Next level in ".
                                    dur(fetchvalue("gsrpg_players","next","username",$arg[4])-time()).".",$usernick);
                            chanopvo(fetchvalue("gsrpg_players","playerid","username",$arg[4]));
                            
                        }
                    }
                }
            }
            elsif (lc($arg[3]) eq 'logout') {
                my @player = fetcharray("gsrpg_players","playerid,online,level,next","nick",$escaped);
                if ($player[1] ne '1') { privmsg("You are not logged in.",$usernick); }
                else {
                    my $pen = int(20 * ($options{penaltystep}**$player[2]));
                    penalize($player[0],'logout',$pen) if $options{penlogout};
                    $db->do("UPDATE gsrpg_players SET online = 0, lastlogout = ".time().
                            " WHERE playerid = $player[0]");
                    questcheck($player[0]);
                    privmsg("You are now logged out.",$usernick);
                }
            }
            elsif (lc($arg[3]) eq 'whoami') {
                my @player = fetcharray("gsrpg_players","username,level,class,next,".
                                        "online,playerid,teamid","nick",$escaped);
                if ($player[4] ne '1') { privmsg("You are not logged in.",$usernick); }
                else {
                    privmsg("You are $player[0], the level $player[1] $player[2]. Next ".
                            "level in ".dur($player[3]-time()).".",$usernick);
                    privmsg("Your itemsum is ".itemsum($player[5]).".",$usernick);
                    privmsg("Your playerid is $player[5] -- http://www.irpg.net/?node=players\;id=$player[5]",$usernick);
                    privmsg("You are a member of team ".
                            fetchvalue("gsrpg_teams","name","teamid",$player[6]).
                            ".",$usernick) if $player[6] > 0;
                    privmsg("You are an admin with level ".adminlevel($usernick)." access.",$usernick) if adminlevel($usernick) > 0;
                }
            }
            elsif (lc($arg[3]) eq 'items') {
                my @player = fetcharray("gsrpg_players","playerid,online","nick",$escaped);
                if ($player[1] ne '1') { privmsg("You are not logged in.",$usernick); }
                else {
                    if ($options{floodwatch}) {
                        privmsg("Sorry, but the items command has been disabled.",$usernick);
                    }
                    else {
                        privmsg("Amulet: \2".fetchitem("amulet",$player[0])."\2 ".
                                isunique($player[0],"amulet"),$usernick);
                        privmsg("Boots: \2".fetchitem("pair_of_boots",$player[0])."\2 ".
                                isunique($player[0],"pair_of_boots"),$usernick);
                        privmsg("Charm: \2".fetchitem("charm",$player[0])."\2 ".
                                isunique($player[0],"charm"),$usernick);
                        privmsg("Gloves: \2".fetchitem("pair_of_gloves",$player[0])."\2 ".
                                isunique($player[0],"pair_of_gloves"),$usernick);
                        privmsg("Helm: \2".fetchitem("helm",$player[0])."\2 ".
                                isunique($player[0],"helm"),$usernick);
                        privmsg("Leggings: \2".fetchitem("set_of_leggings",$player[0])."\2 ".
                                isunique($player[0],"set_of_leggings"),$usernick);
                        privmsg("Ring: \2".fetchitem("ring",$player[0])."\2 ".
                                isunique($player[0],"ring"),$usernick);
                        privmsg("Shield: \2".fetchitem("shield",$player[0])."\2 ".
                                isunique($player[0],"shield"),$usernick);
                        privmsg("Tunic: \2".fetchitem("tunic",$player[0])."\2 ".
                                isunique($player[0],"tunic"),$usernick);
                        privmsg("Weapon: \2".fetchitem("weapon",$player[0])."\2 ".
                                isunique($player[0],"weapon"),$usernick);
                        privmsg("Your itemsum is ".itemsum($player[0]).".",$usernick);
                    }
                }
            }
            elsif (lc($arg[3]) eq 'whois') {
                if ($#arg < 4 || $arg[4] eq '') {
                    privmsg("Syntax of \2WHOIS\2: /msg $curnick WHOIS <username>",$usernick);
                    privmsg("Example: /msg $curnick WHOIS Jake",$usernick);
                }
                elsif (!checkstr($arg[4])) { privmsg("\"$arg[4]\" is an invalid user name.",$usernick); }
                else {
                    my @user = fetcharray("gsrpg_players","playerid,level,class,next,".
                                          "nick,teamid,online,lastlogout,playerid","username",$arg[4]);
                    if (!@user) { privmsg("\"$arg[4]\" is not a user in my database.",$usernick); }
                    else {
                        my $time = $user[7];
                        $time = time() if $user[6] eq '1';
                        privmsg("$user[4] is $arg[4], the level $user[1] $user[2]. ".
                                                      "Next level in ".dur($user[3]-$time).".",$usernick);
                        privmsg("$arg[4] has an itemsum of ".itemsum($user[0]).".",$usernick);
                        privmsg("$arg[4] -- http://www.irpg.net/?node=players\;id=$user[8]",$usernick);

                        privmsg("$arg[4] is a member of team ".
                                fetchvalue("gsrpg_teams","name","teamid",$user[5]).
                                ".",$usernick) if $user[5] > 0;
                    }
                }
            }
            elsif (lc($arg[3]) eq 'lookup') {
                if ($#arg < 4 || $arg[4] eq '') {
                    privmsg("Syntax of \2LOOKUP\2: /msg $curnick LOOKUP <nickname>",$usernick);
                    privmsg("Example: /msg $curnick LOOKUP Jake",$usernick);
                }
                elsif (!checkstr($arg[4])) { privmsg("\"$arg[4]\" is an invalid nick name.",$usernick); }
                else {
                    my $nick = $arg[4];
                    $nick =~ s/\\/\\\\/g if $arg[4] =~ /\\/;
                    my @user = fetcharray("gsrpg_players","playerid,level,class,next,".
                                          "nick,teamid,online,lastlogout,username,playerid","nick",$nick);
                    if (!@user) { privmsg("\"$arg[4]\" is not logged in to any ".
                                          "player in my database.",$usernick); }
                    else {
                        my $time = $user[7];
                        $time = time() if $user[6] eq '1';
                        privmsg("$arg[4] is $user[8], the level $user[1] $user[2]. ".
                                                      "Next level in ".dur($user[3]-$time).".",$usernick);
                        privmsg("$user[8] has an itemsum of ".itemsum($user[0]).".",$usernick);
                        privmsg("$user[8] -- http://www.irpg.net/?node=players\;id=$user[9]",$usernick);
                        privmsg("$user[8] is a member of team ".
                                fetchvalue("gsrpg_teams","name","teamid",$user[5]).
                                ".",$usernick) if $user[5] > 0;
                    }
                }
            }
            elsif (lc($arg[3]) eq 'class') {
                my @player = fetcharray("gsrpg_players","playerid,online","nick",$escaped);
                if (!@player || $player[1] ne '1') { privmsg("You are not logged in.",$usernick); }
                else {
                    if ($arg[4] eq "" || $#arg < 4) {
                        privmsg("Syntax of \2CLASS\2: ".
                                "/msg $curnick CLASS <new class name>",$usernick);
                        privmsg("Class names can be a maximum of ".
                                "50 characters. (don't include the <>'s)",$usernick);
                        privmsg("Example: /msg $curnick CLASS Drunken College Student",$usernick);
                    }
                    elsif (length("@arg[4..$#arg]") > 49) {
                        privmsg("Class names must be 50 characters or shorter.",$usernick); }
                    else {
                        my $class = "@arg[4..$#arg]";
                        if (!checkstr($class)) { privmsg("\"$class\" is an invalid class name.",$usernick); }
                        else {
                            $db->do("UPDATE gsrpg_players SET class = '$class' WHERE playerid = $player[0]");
                            privmsg("Your class has been changed to @arg[4..$#arg].",$usernick);
                        }
                    }
                }
            }
            elsif (lc($arg[3]) eq 'challenge') {
                my @player = fetcharray("gsrpg_players","playerid,online,username,".
                                        "challenge,challenge_times","nick",$escaped);
                if ($player[1] ne '1') { privmsg("You are not logged in.",$usernick); }
                else {
                    if ($player[4] eq '0') {
                        privmsg("This is your first manual challenge. You have an unlimited number of ".
                                "challenges, but each time you use one, the interval you must wait before ".
                                "you are allowed to challenge again increases exponentially.",$usernick);
                        privmsg("If you wish, you may specify a person you wish to challenge by typing ".
                                "\2/msg $curnick CHALLENGE <username>\2. The amount of time you can gain ".
                                "or lose is directly proportional to the the itemsum of the person you ".
                                "challenge. Challenging a player with a higher itemsum can result in a ".
                                "in a larger bonus than someone with a smaller sum, but also can result ".
                                "in a larger penalty.",$usernick);
                        privmsg("If you would rather the bot select a challenger for you, simply type ".
                                "\2/msg $curnick CHALLENGE\2, and the bot will select the player with itemsums ".
                                "directly above and below you. It will then randomly choose one or the ".
                                "other for you to battle.",$usernick);
                        $db->do("UPDATE gsrpg_players SET challenge_times = 1 ".
                                "WHERE nick = '${escaped}'") if $player[4] eq '0';
                    }
                    elsif ($player[3] > time()) {
                        privmsg("You have ".dur($player[3]-time())." left until you may challenge again.",$usernick); }
                    elsif ($#arg < 4 || $arg[4] eq '') {
                        random_challenge($player[0],$usernick); }
                    elsif ($arg[4] ne '' && $#arg >= 4 && $arg[4] =~ /\W/) {
                        privmsg("\"$arg[4]\" is an invalid username. Please try again.",$usernick); }
                    elsif ($arg[4] eq $player[2]) {
                        privmsg("You may not challenge yourself.",$usernick); }
                    elsif ($arg[4] ne '' && $#arg >= 4) {
                        my @check = fetcharray("gsrpg_players","playerid,online","username",$arg[4]);
                        if (!@check) { privmsg("I do not recognize the username \"$arg[4]\".".
                                               "Please try again.",$usernick); }
                        elsif ($check[1] != 1) { privmsg("$arg[4] is currently not online. You can only ".
                                                         "challenge a player who is currently online",$usernick); }
                        else { manual_challenge($player[0],$usernick,$check[0]); }
                    }
                }
            }
            elsif (lc($arg[3]) eq 'up') {
                my @player = fetcharray("gsrpg_players","playerid,online","nick",$escaped);
                if ($player[1] ne '1') { privmsg("You are not logged in.",$usernick); }
                else { chanopvo(fetchvalue("gsrpg_players","playerid","playerid",$player[0])); }
            }
            elsif (lc($arg[3]) eq 'quest') {
                if ($#questers > 0 && length($quest) > 0) {
                    my @questnames;
                    $questnames[$_] = fetchvalue("gsrpg_players","username",
                                                 "playerid",$questers[$_]) for (0..$#questers);
                    privmsg(join(", ",@questnames)." are on a quest to $quest. ".
                            "They complete the quest in ".dur($questtime-time()).".",$usernick);
                }
                else { privmsg("There is no active quest.",$usernick); }
            }
            elsif (lc($arg[3]) eq 'top10') {
                my $query = $db->prepare("SELECT username,level,class,next,online,lastlogout ".
                                         "FROM gsrpg_players ORDER BY level DESC, CASE WHEN ".
                                         "online=1 THEN (next-".time().") ELSE (next-lastlogout) ".
                                         "END ASC LIMIT ".(($options{floodwatch})?"3":"10"));   # fun!
                $query->execute;
                if ($query->rows > 0) {
                    privmsg("$options{botchan} Idle RPG Top Players",$usernick);
                    my $i = 0;
                    while (my @player = $query->fetchrow_array) {
                        $i++;
                        my $time = $player[5];
                        $time = time() if $player[4] eq '1';
                        privmsg("$player[0], the level $player[1] $player[2] ".
                                "is #$i! Next level in ".dur($player[3]-$time).".",$usernick);
                    }
                    $timer = time();
                } 
            }
            elsif (lc($arg[3]) eq 'join') {
                if ($#arg < 4 || $arg[4] eq '') {
                    privmsg("Syntax of \2JOIN\2: ".
                            "/msg $curnick JOIN <teamname> [password]",$usernick);
                    privmsg("Joins the specified team for statistical purposes. ".
                            "Please note that joining a team has no effect on the ".
                            "game or on your player.",$usernick);
                }
                elsif (!checkstr($arg[4])) { privmsg("\"$arg[4]\" is an invalid user name.",$usernick); }
                else {
                    my @player = fetcharray("gsrpg_players","playerid,teamid,online","nick",$escaped);
                    if ($player[2] ne '1') { privmsg("You are not logged in.",$usernick); }
                    else {
                        my @team = fetcharray("gsrpg_teams","teamid,password,name","LOWER(name)",lc($arg[4]));
                        my $curteam = fetchvalue("gsrpg_teams","name","teamid",$player[1]);
                        if (!@team) { privmsg("\"$arg[4]\" is an invalid team name.",$usernick); }
                        elsif (lc($arg[4]) eq lc($curteam)) {
                            privmsg("You are already a member of team $curteam.",$usernick); }
                        elsif ($team[1] ne crypt($arg[5],$team[1])) {
                            privmsg("This team requires a ".
                                                        "valid password to join.",$usernick); }
                        else {
                            $db->do("UPDATE gsrpg_players SET teamid = '$team[0]' ".
                                    "WHERE playerid = $player[0]");
                            privmsg("You are now a member of team $team[2]. Please ".
                                    "visit $options{helpurl} to view other team members and ".
                                    "general team statistics.",$usernick);
                        }
                    }
                }
            }
            elsif (lc($arg[3]) eq 'leave') {
                my @player = fetcharray("gsrpg_players","playerid,teamid,online","nick",$escaped);
                if ($player[2] ne '1') { privmsg("You are not logged in.",$usernick); }
                else {
                    if ($player[1] eq '0') {
                        privmsg("You are currently not a member of any team.",$usernick); }
                    else {
                        $db->do("UPDATE gsrpg_players SET teamid = '0' WHERE playerid = $player[0]");
                        privmsg("You have left your team.",$usernick);
                    }
                }
            }
            elsif (lc($arg[3]) eq 'notice') {
                my @player = fetcharray("gsrpg_players","playerid,online,notice","nick",$escaped);
                if ($player[1] ne '1') { privmsg("You are not logged in.",$usernick); }
                else {
                    if ($#arg < 4 || $arg[4] eq '') {
                        privmsg("Syntax of \2NOTICE\2: /msg $curnick NOTICE <on/off>",$usernick);
                        if (!$options{floodwatch}) {
                            privmsg("This feature controls whether gsrpg sends you messages via ".
                                "privmsg, or via notice. If enabled, you will receive all ".
                                "messages from gsrpg via notice, instead of privmsg.",$usernick);
                            privmsg("You currently have this setting: \2".
                                (($player[2] == 1)?"Enabled":"Disabled")."\2",$usernick);
                        }
                        privmsg("Example: /msg $curnick NOTICE off",$usernick);
                    }
                    elsif ($arg[4] ne '1' && $arg[4] ne '0'
                           && $arg[4] ne 'off' && $arg[4] ne 'on') {
                        privmsg("\"$arg[4]\" is an invalid setting.",$usernick); }
                    else {
                        $db->do("UPDATE gsrpg_players SET notice = '$arg[4]' ".
                                "WHERE playerid = $player[0]") if $arg[4] eq '1' || $arg[4] eq '0';
                        $db->do("UPDATE gsrpg_players SET notice = '".(($arg[4] eq 'on')?1:0)."' ".
                                "WHERE playerid = $player[0]") if $arg[4] eq 'on' || $arg[4] eq 'off';
                        privmsg("Send notice is now: \2".
                                ((fetchvalue("gsrpg_players","notice","playerid",
                                             $player[0]) == 1)?"Enabled":"Disabled")."\2",$usernick);
                    }
                }
            }
            elsif (lc($arg[3]) eq 'chpass') {               
                if (adminlevel($usernick) >= 4) {
                    if ($arg[5] eq '' || $#arg < 5) {
                        privmsg("Syntax of \2CHPASS\2: ".
                                "/msg $curnick CHPASS <username> <password>",$usernick);
                        privmsg("Example: /msg $curnick CHPASS Jake randompassword",$usernick);
                    }
                    else {
                        my $id = fetchvalue("gsrpg_players","playerid","username",$arg[4]);
                        if (!$id) { privmsg("\"$arg[4]\" is an invalid username.",$usernick); }
                        elsif (length($arg[5]) > 20) {
                            privmsg("Passwords should be no longer than 20 characters.",$usernick); }
                        else {
                            $db->do("UPDATE gsrpg_players SET password = '".
                                    crypt($arg[5],mksalt())."' WHERE playerid = $id");
                            privmsg("$arg[4]\'s password has been changed.",$usernick);
                            monitorchanmsg("$usernick: @arg[3..$#arg]");
                        }
                    }
                }
                else { privmsg("You do not have access to this command.",$usernick); }
            }
            elsif (lc($arg[3]) eq 'chclass') {               
                if (adminlevel($usernick) >= 4) {
                    if ($arg[5] eq '' || $#arg < 5) {
                        privmsg("Syntax of \2CHCLASS\2: ".
                                "/msg $curnick CHCLASS <username> <new class name>",$usernick);
                        privmsg("Example: /msg $curnick CHCLASS Jake Random Drunkard",$usernick);
                    }
                    else {
                        my $id = fetchvalue("gsrpg_players","playerid","username",$arg[4]);
                        if (!$id) { privmsg("\"$arg[4]\" is an invalid username.",$usernick); }
                        elsif (length("@arg[5..$#arg]") > 50) {
                            privmsg("Classes should be no longer than 20 characters.",$usernick); }
                        else {
                            my $class = "@arg[5..$#arg]";
                            if (!checkstr($class)) { privmsg("\"$class\" is an invalid class name.",$usernick); }
                            else {
                                $db->do("UPDATE gsrpg_players SET class = '$class' WHERE playerid = $id");
                                privmsg("$arg[4]\'s class has been changed to \"@arg[5..$#arg]\".",$usernick);
                                monitorchanmsg("$usernick: @arg[3..$#arg]");
                            }
                        }
                    }
                }
                else { privmsg("You do not have access to this command.",$usernick); }
            }
            elsif (lc($arg[3]) eq 'chuser') {               
                if (adminlevel($usernick) >= 4) {
                    if ($arg[5] eq '' || $#arg < 5) {
                        privmsg("Syntax of \2CHUSER\2: ".
                                "/msg $curnick CHUSER <user> <newuser>",$usernick);
                        privmsg("Example: /msg $curnick CHUSER Jake Jake2",$usernick);
                    }
                    elsif ($arg[5] =~ /\W/) {
                        privmsg("Usernames should be alphanumeric (a-z,0-9).",$usernick); }
                    else {
                        my $id = fetchvalue("gsrpg_players","playerid","username",$arg[4]);
                        if (!$id) { privmsg("\"$arg[4]\" is an invalid username.",$usernick); }
                        elsif (fetchvalue("gsrpg_players","playerid","username",$arg[5])) {
                            privmsg("That username is already in use.",$usernick); }
                        elsif (length($arg[5]) > 20) {
                            privmsg("Usernames should be no longer than 20 characters.",$usernick); }
                        else {
                            $db->do("UPDATE gsrpg_players SET username = '$arg[5]' WHERE playerid = $id");
                            privmsg("$arg[4]\'s username has been changed to $arg[5].",$usernick);
                            monitorchanmsg("$usernick: @arg[3..$#arg]");
                        }
                    }
                }
                else { privmsg("You do not have access to this command.",$usernick); }
            }
            elsif (lc($arg[3]) eq 'chadmin') {               
                if (adminlevel($usernick) >= 9) {
                    if ($arg[5] eq '' || $#arg < 5) {
                        privmsg("Syntax of \2CHADMIN\2: ".
                                "/msg $curnick CHADMIN <username> <1-10>",$usernick);
                        privmsg("Example: /msg $curnick CHADMIN Jake 3",$usernick);
                    }
                    else {
                        my $id = fetchvalue("gsrpg_players","playerid","username",$arg[4]);
                        if (!$id) { privmsg("\"$arg[4]\" is an invalid username.",$usernick); }
                        elsif (int($arg[5]) < 0 || int($arg[5]) > 10) {
                            privmsg("Admin access should be between zero and ten.",$usernick); }
                        elsif ($arg[4] eq $options{botadmin}) {
                            privmsg("You may not modify the access of the primary bot admin.",$usernick); }
                        else {
                            $db->do("UPDATE gsrpg_players ".
                                    "SET admin = '".int($arg[5])."' WHERE playerid = $id");
                            privmsg("$arg[4]\'s admin level has been ".
                                    "changed to ".int($arg[5]).".",$usernick);
                            monitorchanmsg("$usernick: @arg[3..$#arg]");
                        }
                    }
                }
                else { privmsg("You do not have access to this command.",$usernick); }
            }
            elsif (lc($arg[3]) eq 'noop') {               
                if (adminlevel($usernick) >= 4) {
                    if ($arg[5] eq '' || $#arg < 5) {
                        privmsg("Syntax of \2NOOP\2: ".
                                "/msg $curnick NOOP <username> <on/off>",$usernick);
                        privmsg("Example: /msg $curnick NOOP Jake on",$usernick);
                    }
                    else {
                        my $id = fetchvalue("gsrpg_players","playerid","username",$arg[4]);
                        if (!$id) { privmsg("\"$arg[4]\" is an invalid username.",$usernick); }
                        elsif ($arg[5] ne '1' && $arg[5] ne '0'
                           && $arg[5] ne 'off' && $arg[5] ne 'on') {
                            privmsg("\"$arg[5]\" is an invalid setting.",$usernick); }
                        else {
                            $db->do("UPDATE gsrpg_players SET noop = $arg[5] ".
                                "WHERE playerid = $id") if $arg[5] eq '1' || $arg[5] eq '0';
                            $db->do("UPDATE gsrpg_players SET noop = ".(($arg[5] eq 'on')?1:0).
                                    " WHERE playerid = $id") if $arg[5] eq 'on' || $arg[5] eq 'off';
                            privmsg("No-op on $arg[4] now: \2".
                                ((fetchvalue("gsrpg_players","noop","playerid",
                                             $id) == 1)?"Enabled":"Disabled")."\2",$usernick);
                            monitorchanmsg("$usernick: @arg[3..$#arg]");
                        }
                    }
                }
                else { privmsg("You do not have access to this command.",$usernick); }
            }
            elsif (lc($arg[3]) eq 'push') {               
                if (adminlevel($usernick) >= 6) {
                    if ($arg[5] eq '' || $#arg < 5) {
                        privmsg("Syntax of \2PUSH\2: ".
                                "/msg $curnick PUSH <username> <seconds>",$usernick);
                        privmsg("Example: /msg $curnick PUSH Jake 600",$usernick);
                    }
                    elsif ($arg[5] =~ /\D/) {
                        privmsg("\"$arg[5]\" is not a valid number.",$usernick); }
                    else {
                        my @id = fetcharray("gsrpg_players","playerid,next,".
                                            "level,online","username",$arg[4]);
                        if (!@id) { privmsg("\"$arg[4]\" is an invalid username.",$usernick); }
                        elsif ($id[3] ne '1') {
                            privmsg("You may only push a player who is currently online.",$usernick); }
                        elsif ($arg[5] >= ($id[1]-time())) {
                            privmsg("$arg[5] is longer than $arg[4]\'s time to level.",$usernick); }
                        else {
                            $db->do("UPDATE gsrpg_players SET next = next-$arg[5] WHERE playerid = $id[0]");
                            my $next = fetchvalue("gsrpg_players","next","playerid",$id[0]);
                            privmsg("Pushed $arg[4] ahead $arg[5] seconds towards level ".
                                    ($id[2]+1).". Next level in ".dur($next-time()).".",$usernick);
                            chanmsg("$usernick has pushed $arg[4] $arg[5] seconds towards level ".
                                    ($id[2]+1).". Next level in ".dur($next-time()).".")
                                    if $options{announcepush} == 1;
                            logmod($id[0],'pu',$arg[5],1);
                            monitorchanmsg("$usernick: @arg[3..$#arg]");
                        }
                    }
                }
                else { privmsg("You do not have access to this command.",$usernick); }
            }
            elsif (lc($arg[3]) eq 'create') {               
                if (adminlevel($usernick) >= 4) {
                    if ($arg[7] eq '' || $#arg < 7) {
                        privmsg("Syntax of \2CREATE\2: ".
                                "/msg $curnick CREATE <teamname> <owner> <password/null> ".
                                "<description>",$usernick);
                        privmsg("Example: /msg $curnick CREATE Fappers Jake somepass a ".
                                "whole bunch of fappers..",$usernick);
                    }
                    elsif (!checkstr($arg[4])) { privmsg("\"$arg[4]\" is an invalid team name.",$usernick); }
                    elsif (!checkstr($arg[5])) { privmsg("\"$arg[5]\" is an invalid user name.",$usernick); }
                    elsif (!checkstr($arg[6])) { privmsg("\"$arg[6]\" is an invalid password.",$usernick); }
                    elsif (!checkstr("@arg[7..$#arg]")) {
                        privmsg("\"@arg[7..$#arg]\" is an invalid description.",$usernick); }
                    else {
                        my $id = fetchvalue("gsrpg_players","playerid","username",$arg[5]);
                        if (!$id) { privmsg("\"$arg[5]\" is an invalid username.",$usernick); }
                        elsif (length($arg[4]) > 20) {
                            privmsg("Team names should no longer than 20 characters.",$usernick); }
                        elsif (length("@arg[7..$#arg]") > 60) {
                            privmsg("Class names should no longer than 60 characters.",$usernick); }
                        elsif (fetchvalue("gsrpg_teams","teamid","name",$arg[4])) {
                            privmsg("That team name is already in use.",$usernick); }
                        else {
                            $db->do("INSERT INTO gsrpg_teams (teamid,name,description,owner,created,".
                                    "password) VALUES (nextval('public.gsrpg_teams_teamid_seq'::text),".
                                    "'$arg[4]','@arg[7..$#arg]','$id','".time()."','".
                                    (($arg[6] ne 'null')?crypt($arg[6],mksalt()):'')."')");
                            my $teamid = fetchvalue("gsrpg_teams","teamid","name",$arg[4]);
                            $db->do("UPDATE gsrpg_players SET teamid = '$teamid' WHERE playerid = $id");
                            privmsg("Successfully created team \"$arg[4]\"".
                                    "with $arg[5] as the owner.",$usernick);
                            monitorchanmsg("$usernick: @arg[3..$#arg]");
                        }
                    }
                }
                else { privmsg("You do not have access to this command.",$usernick); }
            }
            elsif (lc($arg[3]) eq 'chteam') {               
                if (adminlevel($usernick) >= 4) {
                    if ($arg[5] eq '' || $#arg < 5) {
                        privmsg("Syntax of \2CHTEAM\2: ".
                                "/msg $curnick CHTEAM <team> <newteam>",$usernick);
                        privmsg("Example: /msg $curnick CHTEAM Idlers Talkers",$usernick);
                    }
                    elsif (!checkstr($arg[4])) { privmsg("\"$arg[4]\" is an invalid team name.",$usernick); }
                    elsif (!checkstr($arg[5])) { privmsg("\"$arg[5]\" is an invalid user name.",$usernick); }
                    else {
                        my $id = fetchvalue("gsrpg_teams","teamid","name",$arg[4]);
                        if (!$id) {
                            privmsg("\"$arg[4]\" is an invalid team name.",$usernick); }
                        elsif (fetchvalue("gsrpg_teams","teamid","name",$arg[5])) {
                            privmsg("That team name is already in use.",$usernick); }
                        elsif (length($arg[5]) > 20) {
                            privmsg("Team names should be no longer than 20 characters.",$usernick); }
                        else {
                            $db->do("UPDATE gsrpg_teams SET name = '$arg[5]' WHERE teamid = $id");
                            privmsg("$arg[4]\'s team name has been changed to $arg[5].",$usernick);
                            monitorchanmsg("$usernick: @arg[3..$#arg]");
                        }
                    }
                }
                else { privmsg("You do not have access to this command.",$usernick); }
            }
            elsif (lc($arg[3]) eq 'chteampass') {               
                if (adminlevel($usernick) >= 4) {
                    if ($arg[5] eq '' || $#arg < 5) {
                        privmsg("Syntax of \2CHTEAMPASS\2: ".
                                "/msg $curnick CHTEAMPASS <teamname> <password>",$usernick);
                        privmsg("Example: /msg $curnick CHTEAMPASS Idlers randompassword",$usernick);
                    }
                    elsif (!checkstr($arg[4])) { privmsg("\"$arg[4]\" is an invalid team name.",$usernick); }
                    elsif (!checkstr($arg[5])) { privmsg("\"$arg[5]\" is an invalid password.",$usernick); }
                    else {
                        my $id = fetchvalue("gsrpg_teams","teamid","name",$arg[4]);
                        if (!$id) {
                            privmsg("\"$arg[4]\" is an invalid team name.",$usernick); }
                        elsif (length($arg[5]) > 20) {
                            privmsg("Passwords should be no longer than 20 characters.",$usernick); }
                        else {
                            $db->do("UPDATE gsrpg_teams SET password = '".
                                    (($arg[5] eq 'null')?'':crypt($arg[5],mksalt()))."' WHERE teamid = $id");
                            privmsg("$arg[4]\'s password has been changed.",$usernick);
                            monitorchanmsg("$usernick: @arg[3..$#arg]");
                        }
                    }
                }
                else { privmsg("You do not have access to this command.",$usernick); }
            }
            elsif (lc($arg[3]) eq 'chteamdesc') {               
                if (adminlevel($usernick) >= 4) {
                    if ($arg[5] eq '' || $#arg < 5) {
                        privmsg("Syntax of \2CHDESC\2: ".
                                "/msg $curnick CHTEAMDESC <teamname> <new description>",$usernick);
                        privmsg("Example: /msg $curnick CHTEAMDESC Idlers The idle team!",$usernick);
                    }
                    elsif (!checkstr($arg[4])) { privmsg("\"$arg[4]\" is an invalid team name.",$usernick); }
                    elsif (!checkstr("@arg[5..$#arg]")) {
                        privmsg("\"@arg[5..$#arg]\" is an invalid description.",$usernick); }
                    else {
                        my $id = fetchvalue("gsrpg_teams","teamid","name",$arg[4]);
                        if (!$id) { privmsg("\"$arg[4]\" is an invalid team name.",$usernick); }
                        elsif (length("@arg[5..$#arg]") > 60) {
                            privmsg("Descriptions should be no longer than 20 characters.",$usernick); }
                        else {
                            $db->do("UPDATE gsrpg_teams ".
                                    "SET description = '@arg[5..$#arg]' WHERE teamid = $id");
                            privmsg("$arg[4]\'s description has been changed ".
                                    "to \"@arg[5..$#arg]\".",$usernick);
                            monitorchanmsg("$usernick: @arg[3..$#arg]");
                        }
                    }
                }
                else { privmsg("You do not have access to this command.",$usernick); }
            }
            elsif (lc($arg[3]) eq 'die') {               
                if (adminlevel($usernick) >= 8) {
                    monitorchanmsg("$usernick: @arg[3..$#arg]");
                    $SIG{ALRM} = 0;
                    alarm(0);
                    closedb();
                    $reconnect = 0;
                    puttext("QUIT :Received DIE from $usernick");
                    alog("Disconnected by manual die from $usernick.",0);
                }
                else { privmsg("You do not have access to this command.",$usernick); }
            }
            elsif (lc($arg[3]) eq 'peval') {
                if (adminlevel($usernick) >= 8) {
                    privmsg($_, $usernick) for eval "@arg[4..$#arg]";
                    privmsg("EVAL ERROR: $@",$usernick) if $@;
                }
                else { privmsg("You do not have access to this command.",$usernick); }
            }
            elsif (lc($arg[3]) eq 'hog') {               
                if (adminlevel($usernick) >= 4) {
                    if ($arg[4] ne '' && $#arg >= 4 && $arg[4] =~ /\W/) {
                        privmsg("\"$arg[4]\" is an invalid username. Please try again.",$usernick);
                    } elsif ($arg[4] ne '' && $#arg >= 4) {
                        my @check = fetcharray("gsrpg_players","playerid,online","username",$arg[4]);
                        if (!@check) { privmsg("I do not recognize the username \"$arg[4]\".".
                            "Please try again.",$usernick); }
                        elsif ($check[1] != 1) { privmsg("$arg[4] is currently not online. You can only ".
                            "hog a player who is currently online",$usernick); }
                        else {
                            chanmsg("$usernick has summoned the Hand of God.");
                            target_hog($check[0]); 
                            monitorchanmsg("$usernick: @arg[3..$#arg]");
                        }
                    } else {
                        chanmsg("$usernick has summoned the Hand of God.");
                        hog();
                        monitorchanmsg("$usernick: @arg[3..$#arg]");
                    }
                }
                else { privmsg("You do not have access to this command.",$usernick); }
            }

#Harms Rejoin Patch version 1.0
            elsif (lc($arg[3]) eq 'rejoin') {
                if (adminlevel($usernick) >= 5) {
                puttext("JOIN $options{botchan}");
                chanmsg("REJOIN initiated by $usernick.");
                monitorchanmsg("$usernick: @arg[3..$#arg]");
                }
                else { privmsg("You do not have access to this command.",$usernick); }
            }
#End Harms Rejoin Patch version 1.0

#Harms Rejoin Patch version 1.0
            elsif (lc($arg[3]) eq 'mrejoin') {
                if (adminlevel($usernick) >= 5) {
                puttext("JOIN $options{monitorchan} $options{monitorchanpass}") if $options{monitor};
                monitorchanmsg("$usernick: @arg[3..$#arg]");
                }
                else { privmsg("You do not have access to this command.",$usernick); }
            }
#End Harms Rejoin Patch version 1.0

            elsif (lc($arg[3]) eq 'dump') {               
                if (adminlevel($usernick) >= 8) { puttext("@arg[4..$#arg]"); }
                else { privmsg("You do not have access to this command.",$usernick); }
            }
            elsif (lc($arg[3]) eq 'query') {               
                if (adminlevel($usernick) >= 8) {
                    privmsg("Query successful.",$usernick) if $db->do("@arg[4..$#arg]"); }
                else { privmsg("You do not have access to this command.",$usernick); }
            }
            elsif (lc($arg[3]) eq 'editadmin') {
                if (adminlevel($usernick) >= 8) {
                    if ($arg[5] eq '' || $#arg < 5) {
                        privmsg("Syntax of \2EDITADMIN\2: ".
                                "/msg $curnick EDITADMIN <username> <level 0-9>",$usernick);
                        privmsg("Example: /msg $curnick EDITADMIN Jake 5",$usernick);
                    }
                    elsif ($arg[5] =~ /\D/) {
                        privmsg("\"$arg[5]\" is not a valid number.",$usernick); }
                    elsif ($arg[5] < 0 || $arg[5] > 9) {
                        privmsg("Admin level must be between 0 and 9.",$usernick); }
                    else {
                        my @id = fetchvalue("gsrpg_players","playerid,admin","username",$arg[4]);
                        if (!@id) { privmsg("\"$arg[4]\" is an invalid username.",$usernick); }
                        elsif ($id[1] > adminlevel($usernick)) {
                            privmsg("\"$arg[5]\" outranks you.",$usernick); }
                        else {
                            $db->do("UPDATE gsrpg_players SET admin = $arg[5] WHERE playerid = $id[0]");
                            privmsg("$arg[4] is now admin level $arg[5].",$usernick);
                            monitorchanmsg("$usernick: @arg[3..$#arg]");
                        }
                    }
                } else { privmsg("You do not have access to this command.",$usernick); }
            }
            elsif (lc($arg[3]) eq 'cheat') { privmsg("Me?! Cheat?! Never!",$usernick); }
            elsif (lc($arg[3]) eq 'restart') {               
                if (adminlevel($usernick) >= 9) {
                    monitorchanmsg("$usernick: @arg[3..$#arg]");
                    local($SIG{ALRM}) = 0;
                    alarm(0);
                    $reconnect = 0;
                    puttext("QUIT :Received RESTART from $usernick");
                    alog("Manual restart triggered by $usernick.",0);
                    system "perl $0";
                }
                else { privmsg("You do not have access to this command.",$usernick); }
            }
            elsif (lc($arg[3]) eq 'alert') {               
                if (adminlevel($usernick) >= 5) { 
                    chanmsg("ALERT from $usernick: @arg[4..$#arg]"); 
                    monitorchanmsg("$usernick: @arg[3..$#arg]");
                }
                else { privmsg("You do not have access to this command.",$usernick); }
            }
            elsif (lc($arg[3]) eq 'reloadconfig') {
                if (adminlevel($usernick) >= 5) {
                    %options = loadconfig();
                    privmsg("Reloaded $config.",$usernick);
                    monitorchanmsg("$usernick: @arg[3..$#arg]");
                }
                else { privmsg("You do not have access to this command.",$usernick); }
            }
            elsif (lc($arg[3]) eq 'info') {
                if (adminlevel($usernick) > 0) {
                    my $info = sprintf("I am version $version and have been online for %s [%.2fkb in/%.2fkb out], ".
                                       "with %d players online and %d players stored in the database",
                                         dur(time()-$startup),$inbytes/1024,$outbytes/1024,
                                         fetchvalue("gsrpg_players","COUNT(playerid)","online","1"),
                                         fetchvalue("gsrpg_players","COUNT(playerid)","gameid","1"));
                    privmsg($info,$usernick);
                }
                else { privmsg("You do not have access to this command.",$usernick); }
            }
            elsif (lc($arg[3]) eq 'del') {
                if (adminlevel($usernick) >= 5) {
                    if ($arg[4] eq '' || $#arg < 4) {
                        privmsg("Syntax of \2DEL\2: /msg $curnick DEL <username>",$usernick);
                        privmsg("Example: /msg $curnick DEL Jake",$usernick);
                    }
                    else {
                        my $id = fetchvalue("gsrpg_players","playerid","username",$arg[4]);
                        if (!$id) { privmsg("\"$arg[4]\" is an invalid username.",$usernick); }
                        else {
                            $db->do("DELETE FROM gsrpg_players WHERE playerid = '$id'");
                            $db->do("DELETE FROM gsrpg_items WHERE playerid = '$id'");
                            $db->do("DELETE FROM gsrpg_penalties WHERE playerid = '$id'");
                            $db->do("DELETE FROM gsrpg_modifiers WHERE playerid = '$id'");
                            $db->do("DELETE FROM gsrpg_itemrecords WHERE playerid = '$id'");
                            privmsg("Removed $arg[4] from my database.",$usernick);
                            monitorchanmsg("$usernick: @arg[3..$#arg]");
                        }
                    }
                }
            }
            else {
                my @player = fetcharray("gsrpg_players","playerid,next,level,online","nick",$escaped);
                if ($player[3] eq '1') {
                    next() if $_ =~ /: $/;
                    my $pen = int((length("@arg[3..$#arg]")-1) * ($options{penaltystep}**$player[2]));
                    penalize($player[0],'text',$pen) if $options{penprivmsg};
                    questcheck($player[0]) if $options{penprivmsg};
                }
            }
        }
        elsif (lc($arg[2]) eq lc($options{botchan})) {
           my @player = fetcharray("gsrpg_players","playerid,next,level,online","nick",$escaped);
            if ($player[3] eq '1') {
                next() if $_ =~ /: $/;
                my $pen = int((length("@arg[3..$#arg]")-1) * ($options{penaltystep}**$player[2]));
                penalize($player[0],'text',$pen) if $options{penchannel};
                questcheck($player[0]) if $options{penchannel};
            }
        }
        else {
            # disabled right now; uncomment if you know what you're doing
            #if (index(lc("@arg[3..$#arg]"),"http:") != -1 &&
            #   (time()-$onchan{$usernick}) < 180 && !(adminlevel($usernick) > 0) &&
            #    lc($arg[2]) eq lc($options{botchan})) {
            #        puttext("CHANSERV addtimedban $options{botchan} $usernick 1d No advertising [1 day ban]");
            #}
            #elsif (index(lc("@arg[3..$#arg]"),"#") != -1 && !(adminlevel($usernick) > 0) &&
            #      (time()-$onchan{$usernick}) < 180 && lc($arg[2]) eq lc($options{botchan})) {
            #        puttext("CHANSERV addtimedban $options{botchan} $usernick 1d No advertising [1 day ban]");
            #}
        }
    }
}

closedb();
print "Connection to server failed.\n" if $verbose;
local($SIG{ALRM}) = 0;
alarm(0);
if ($reconnect) {
    if ($conn_tries < $options{maxtries}) {
        alog("Connection to server failed.. attemping to reconnect.",0);
        goto("CONNECT");
    }
    else {
        alog("Maximum connection tries limit reached. Terminating...",0);
        print "Connection to server failed after $conn_tries attempts.\n" if $verbose || $debug;
    }
}

sub loadconfig() {
    alog("Could not read from $config",1) if ! -r $config;
    open(CFG,$config);
    my %configarray;
    while (chomp(my $l = <CFG>)) {
        next() if $l eq '' || $l =~ /^[\W|#]/;  # skip over comments and null lines
        $l =~ s/[\r\n]//g;
        $l =~ s/^\s+|\s+$//g;
        my @pair = split(/ /,$l,2);
        if ($pair[1] ne '') { $configarray{$pair[0]} = $pair[1]; }
        else { $configarray{$l} = ''; }
    }
    close CFG;
    return %configarray;
}

sub opendb {        # creates the database object
    my $host = "dbi:Pg:dbname=$options{database}";
    $host .= ";port=$options{dbport}" if length($options{dbport}) > 0;
    $db = DBI->connect($host,$options{dbuser}, $options{dbpass},
                      { ShowErrorStatement => 1 }) or
                      alog("Could not connect to database server; $DBI::errstr",1);
    $db->{HandleError} = sub {
        my $msg = shift;
        open(D,">>$options{logfile}");
        print D ts()."$msg\n";
        close D;
        print "$msg\n" if $debug;
    };
    alog("Could not create database connection: $!",1) unless $db;
    my $lastquery = $db->prepare("SELECT timer FROM gsrpg_log LIMIT 1");
    $lastquery->execute;
    $lastquit = ($lastquery->fetchrow_array)[0];
    $lastquery->finish;
    undef $lastquery;
    if (!$lastquit) {       # first start; we don't have a lastquit yet
        $db->do("INSERT INTO gsrpg_log (timer) VALUES (".time().")");
        $lastquit = 0;
    }
}

sub closedb { $db->disconnect if $db; }     # guess what this does?

sub puttext {       # outputs raw text to the server
    return undef unless $sock;
    my $text = shift;
    $text =~ s/[[:cntrl:]]//g if $options{stripcodes};
    print $sock "$text\r\n";
    print "-> $text\n" if $debug;
    $outbytes += length($text)+2;
}

sub chanmsg {       # sends text to the bot channel 
    my $text = shift;
    privmsg($text,$options{botchan});
}

sub monitorchanmsg {       # sends text to the monitor channel 
    my $text = shift;
    privmsg($text,$options{monitorchan});
}

sub privmsg {       # sends text to an individual user
    my $text = shift;
    my $target = shift;
    while (length($text)) {
        puttext(((fetchvalue("gsrpg_players","notice","nick",$target) ne '1')
                 ?"PRIVMSG":"NOTICE")." $target :".substr($text,0,450));
        substr($text,0,450)="";
    }
}

sub massmodes {
    my @massmodes = keys %auto_login;
    my $modes = ' '; my $nicks = ' '; my @cur;
    for (0..$#massmodes) {
        @cur = fetcharray("gsrpg_players","level,noop,nick","playerid",$massmodes[$_]);
        next() if $cur[1] eq '1';
        if (($_ % $modespl) == 0 && $_ != 0) {
            puttext("MODE $options{botchan}$modes$nicks");
            $modes = ' ';
            $nicks = ' ' ;
        }
        if ($options{givevoice} && $cur[0] >= $options{voicelevel}
            && $cur[0] < $options{oplevel}) { $modes .= "+v"; $nicks .= " $cur[2]"; }
        elsif ($options{giveops} && $cur[0] >= $options{oplevel}) {
            $modes .= "+o"; $nicks .= " $cur[2]"; }
    }
    puttext("MODE $options{botchan}$modes$nicks");
}

sub chanopvo {      # ops or voices a user according to XML settings
    my $id = shift or return undef;
    my @noop = fetcharray("gsrpg_players","noop,nick,level","playerid",$id);
    return unless $noop[0] ne '1';
    puttext("MODE $options{botchan} +v $noop[1]") if $options{givevoice}
        && $noop[2] < $options{oplevel} && $noop[2] >= $options{voicelevel};
    puttext("MODE $options{botchan} +o $noop[1]") if $options{giveops}
        && $noop[2] >= $options{oplevel};
}

sub rpcheck {       # the game~! triggers every 5 seconds
    if (((time() - $lastalarm) > 300) || (($lastalarm - time()) > 300)) {
        my $diff;
        $diff = time()-($lastalarm+5) if (time() - $lastalarm) > 300;
        $diff = ($lastalarm+5)-time() if ($lastalarm - time()) > 300;
        $db->do("UPDATE gsrpg_players SET next=next+$diff, challenge=challenge+$diff, ".
                "idled=idled+$diff WHERE online = 1");
    }
    hog() if rand(1500) < 1;
    team_battle() if rand(500) < 1;
    calamity() if rand(1000) < 1;
    godsend() if rand(1000) < 1;
    level_challenge() if rand(1000) < 1;
    if ((time() - $questcheck) > 10800) {       # three hours
        if ($#questers < 1) { quest(); }
        elsif ($#questers > 0 && length($quest) > 0) {
            my @questnames;
            $questnames[$_] = fetchvalue("gsrpg_players","username",
                                         "playerid",$questers[$_]) for (0..$#questers);
            chanmsg(join(", ",@questnames)." are on a quest to $quest. ".
                    "They will complete the quest in ".dur($questtime-time()).".");
            $questcheck = time();
        }
    }
    if (time() > $questtime && $#questers > 0) {
        my @questnames;
        $questnames[$_] = fetchvalue("gsrpg_players","username",
                                     "playerid",$questers[$_]) for (0..$#questers);
        chanmsg(join(", ",@questnames)." have blessed the realm by ".
                "completing their quest to $quest. 25% of their burden is eliminated.");
        $db->do("UPDATE gsrpg_players SET next=next-ROUND((next-".time().")*0.75) ".
                "WHERE playerid = $questers[$_]") for (0..$#questers);
        logmod($questers[$_],'qu',fetchvalue("gsrpg_players",
                                             "ROUND((next-".time().")*0.25)",
                                             "playerid",$questers[$_]),1) for (0..$#questers);
        undef @questers; $questtime = 0;
        $questcheck = time();
    }
    my $query = $db->prepare("SELECT playerid,username,level,class,next FROM gsrpg_players ".
                             "WHERE online = 1 AND ".time()." >= next");

    $query->execute;
    if ($query->rows > 0) {
        while (my @player = $query->fetchrow_array) {
            my $next = int($options{baselevel}*($options{levelstep}**($player[2]+1)));
            $db->do("UPDATE gsrpg_players SET level=level+1, ".
                    "next = ".($next+time())." WHERE playerid = $player[0]");
            chanmsg("$player[1], the $player[3] has attained level ".
                    ($player[2]+1)."! Next level in ".dur($next).".");
            find_item($player[0]);
            level_challenge($player[0]);
            chanopvo($player[0]);
        }
    }

    $query->finish;
    puttext("NICK $options{botnick}") if $curnick ne $options{botnick};
    if ((time() - $timer) > 21600) {        # six hours
        my $query = $db->prepare("SELECT username,level,class,next,online,lastlogout ".
                                 "FROM gsrpg_players ORDER BY level DESC, CASE WHEN online=1 ".
                                 "THEN (next-".time().") ELSE (next-lastlogout) END ASC LIMIT 5");
        $query->execute;
        if ($query->rows > 0) {
            chanmsg("$options{botchan} Idle RPG Top Players");
            my $i = 0;
            while (my @player = $query->fetchrow_array) {
                $i++;
                my $time = $player[5];
                $time = time() if $player[4] eq '1';
                chanmsg("$player[0], the level $player[1] $player[2] ".
                        "is #$i! Next level in ".dur($player[3]-$time).".");
            }
        }
        $query->finish;
        backup() if $options{backup};
        $timer = time();
    }
    if ((time() - $chantime) > 300) {        # fifteen minutes
        chanlog() if $options{chanlog} ne '';
        $chantime = time();
    }
    $db->do("UPDATE gsrpg_log SET \"timer\" = ".time());
    $lastalarm = time();
    $SIG{ALRM} = \&rpcheck;
    alarm($alarmint);
}

sub find_item {     # selects an item for a player
    my $id = shift;
    my $playerlevel = fetchvalue("gsrpg_players","level","playerid",$id);
    my @types = ("amulet","charm","helm","pair_of_boots","pair_of_gloves",
                 "ring","set_of_leggings","shield","tunic","weapon");
    my $type = $types[rand @types];
    my $level = 1;
    for my $num (1..int($playerlevel*1.5)) {
        if (rand(1.4**($num/4)) < 1) { $level = $num; }
    }
    if ($playerlevel >= 20 && rand(60) < 1) {
        my $ulevel = 50+int(rand(15));
        if ($ulevel >= $level && $ulevel > fetchitem("weapon",$id)
            && !fetchitem("unique_weapon",$id)) {
            privmsg("The light of the gods shines down upon you! You have found the ".
            "level $ulevel ".uitems(1)."! Your enemies ".
            "fall before you as you anticipate their every move.",
            fetchvalue("gsrpg_players","nick","playerid",$id));
           $db->do("UPDATE gsrpg_items SET weapon = '$ulevel', ".
                   "unique_weapon = '1' WHERE playerid = $id");
           $db->do("INSERT INTO gsrpg_itemrecords ( playerid,timestamp,type,level,action,isunique ) ".
                   "VALUES ( '$id','".time()."','weapon','$ulevel','1','1' )");
           return;
        }
    }
    if ($playerlevel >= 23 && rand(60) < 1) {
        my $ulevel = 65+int(rand(15));
        if ($ulevel >= $level && $ulevel > fetchitem("ring",$id)
            && !fetchitem("unique_ring",$id)) {
            privmsg("The light of the gods shines down upon you! You have found the ".
            "level $ulevel ".uitems(2)."! Your enemies ".
            "fall before you as you anticipate their every move.",
            fetchvalue("gsrpg_players","nick","playerid",$id));
           $db->do("UPDATE gsrpg_items SET ring = '$ulevel', ".
                   "unique_ring = '2' WHERE playerid = $id");
           $db->do("INSERT INTO gsrpg_itemrecords ( playerid,timestamp,type,level,action,isunique ) ".
                   "VALUES ( '$id','".time()."','ring','$ulevel','1','2' )");
           return;
        }
    }
    if ($playerlevel >= 26 && rand(60) < 1) {
        my $ulevel = 80+int(rand(15));
        if ($ulevel >= $level && $ulevel > fetchitem("pair_of_gloves",$id)
            && !fetchitem("unique_pair_of_gloves",$id)) {
            privmsg("The light of the gods shines down upon you! You have found the ".
            "level $ulevel ".uitems(3)."! Your enemies ".
            "fall before you as you anticipate their every move.",
            fetchvalue("gsrpg_players","nick","playerid",$id));
           $db->do("UPDATE gsrpg_items SET pair_of_gloves = '$ulevel', ".
                   "unique_pair_of_gloves = '3' WHERE playerid = $id");
           $db->do("INSERT INTO gsrpg_itemrecords ( playerid,timestamp,type,level,action,isunique ) ".
                   "VALUES ( '$id','".time()."','pair_of_gloves','$ulevel','1','3' )");
           return;
        }
    }
    if ($playerlevel >= 29 && rand(70) < 1) {
        my $ulevel = 95+int(rand(15));
        if ($ulevel >= $level && $ulevel > fetchitem("tunic",$id)
            && !fetchitem("unique_tunic",$id)) {
            privmsg("The light of the gods shines down upon you! You have found the ".
            "level $ulevel ".uitems(4)."! Your enemies ".
            "fall before you as you anticipate their every move.",
            fetchvalue("gsrpg_players","nick","playerid",$id));
           $db->do("UPDATE gsrpg_items SET tunic = '$ulevel', ".
                   "unique_tunic = '4' WHERE playerid = $id");
           $db->do("INSERT INTO gsrpg_itemrecords ( playerid,timestamp,type,level,action,isunique ) ".
                   "VALUES ( '$id','".time()."','tunic','$ulevel','1','4' )");
           return;
        }
    }
    if ($playerlevel >= 32 && rand(70) < 1) {
        my $ulevel = 110+int(rand(15));
        if ($ulevel >= $level && $ulevel > fetchitem("pair_of_boots",$id)
            && !fetchitem("unique_pair_of_boots",$id)) {
            privmsg("The light of the gods shines down upon you! You have found the ".
            "level $ulevel ".uitems(5)."! Your enemies ".
            "fall before you as you anticipate their every move.",
            fetchvalue("gsrpg_players","nick","playerid",$id));
           $db->do("UPDATE gsrpg_items SET pair_of_boots = '$ulevel', ".
                   "unique_pair_of_boots = '5' WHERE playerid = $id");
           $db->do("INSERT INTO gsrpg_itemrecords ( playerid,timestamp,type,level,action,isunique ) ".
                   "VALUES ( '$id','".time()."','pair_of_boots','$ulevel','1','5' )");
           return;
        }
    }
    if ($playerlevel >= 35 && rand(70) < 1) {
        my $ulevel = 125+int(rand(15));
        if ($ulevel >= $level && $ulevel > fetchitem("shield",$id)
            && !fetchitem("unique_shield",$id)) {
            privmsg("The light of the gods shines down upon you! You have found the ".
            "level $ulevel ".uitems(6)."! Your enemies ".
            "fall before you as you anticipate their every move.",
            fetchvalue("gsrpg_players","nick","playerid",$id));
           $db->do("UPDATE gsrpg_items SET shield = '$ulevel', ".
                   "unique_shield = '6' WHERE playerid = $id");
           $db->do("INSERT INTO gsrpg_itemrecords ( playerid,timestamp,type,level,action,isunique ) ".
                   "VALUES ( '$id','".time()."','shield','$ulevel','1','6' )");
           return;
        }
    }
    if ($playerlevel >= 38 && rand(80) < 1) {
        my $ulevel = 140+int(rand(15));
        if ($ulevel >= $level && $ulevel > fetchitem("amulet",$id)
            && !fetchitem("unique_amulet",$id)) {
            privmsg("The light of the gods shines down upon you! You have found the ".
            "level $ulevel ".uitems(7)."! Your enemies ".
            "fall before you as you anticipate their every move.",
            fetchvalue("gsrpg_players","nick","playerid",$id));
           $db->do("UPDATE gsrpg_items SET amulet = '$ulevel', ".
                   "unique_amulet = '7' WHERE playerid = $id");
           $db->do("INSERT INTO gsrpg_itemrecords ( playerid,timestamp,type,level,action,isunique ) ".
                   "VALUES ( '$id','".time()."','amulet','$ulevel','1','7' )");
           return;
        }
    }
    if ($playerlevel >= 41 && rand(80) < 1) {
        my $ulevel = 155+int(rand(15));
        if ($ulevel >= $level && $ulevel > fetchitem("ring",$id)
            && !fetchitem("unique_ring",$id)) {
            privmsg("The light of the gods shines down upon you! You have found the ".
            "level $ulevel ".uitems(8)."! Your enemies ".
            "fall before you as you anticipate their every move.",
            fetchvalue("gsrpg_players","nick","playerid",$id));
           $db->do("UPDATE gsrpg_items SET ring = '$ulevel', ".
                   "unique_ring = '8' WHERE playerid = $id");
           $db->do("INSERT INTO gsrpg_itemrecords ( playerid,timestamp,type,level,action,isunique ) ".
                   "VALUES ( '$id','".time()."','ring','$ulevel','1','8' )");
           return;
        }
    }
    if ($playerlevel >= 44 && rand(80) < 1) {
        my $ulevel = 170+int(rand(15));
        if ($ulevel >= $level && $ulevel > fetchitem("helm",$id)
            && !fetchitem("unique_helm",$id)) {
            privmsg("The light of the gods shines down upon you! You have found the ".
            "level $ulevel ".uitems(9)."! Your enemies ".
            "fall before you as you anticipate their every move.",
            fetchvalue("gsrpg_players","nick","playerid",$id));
           $db->do("UPDATE gsrpg_items SET helm = '$ulevel', ".
                   "unique_helm = '9' WHERE playerid = $id");
           $db->do("INSERT INTO gsrpg_itemrecords ( playerid,timestamp,type,level,action,isunique ) ".
                   "VALUES ( '$id','".time()."','helm','$ulevel','1','9' )");
           return;
        }
    }
    if ($playerlevel >= 47 && rand(90) < 1) {
        my $ulevel = 185+int(rand(15));
        if ($ulevel >= $level && $ulevel > fetchitem("weapon",$id)
            && !fetchitem("unique_weapon",$id)) {
            privmsg("The light of the gods shines down upon you! You have found the ".
            "level $ulevel ".uitems(10)."! Your enemies ".
            "fall before you as you anticipate their every move.",
            fetchvalue("gsrpg_players","nick","playerid",$id));
           $db->do("UPDATE gsrpg_items SET weapon = '$ulevel', ".
                   "unique_weapon = '10' WHERE playerid = $id");
           $db->do("INSERT INTO gsrpg_itemrecords ( playerid,timestamp,type,level,action,isunique ) ".
                   "VALUES ( '$id','".time()."','weapon','$ulevel','1','10' )");
           return;
        }
    }
    my $tmp = $type;
    $tmp =~ s/_/ /g;
    if ($level > fetchitem($type,$id)) {
        privmsg("You found a level $level $tmp. Your current $tmp is only level ".
                fetchitem($type,$id).", so it seems Luck is with you.",
                fetchvalue("gsrpg_players","nick","playerid",$id));
        $db->do("UPDATE gsrpg_items SET $type = $level WHERE playerid = $id");
        $db->do("INSERT INTO gsrpg_itemrecords (playerid,timestamp,type,level,action,isunique) ".
                "VALUES ( '$id','".time()."','$type','$level','1','0' )");
    }
    else {
        privmsg("You found a level $level $tmp. Your current $tmp is level ".
                fetchitem($type,$id).", so it seems Luck is against you.",
                fetchvalue("gsrpg_players","nick","playerid",$id));
        $db->do("INSERT INTO gsrpg_itemrecords (playerid,timestamp,type,level,action,isunique) ".
                "VALUES ( '$id','".time()."','$type','$level','0','0' )");
    }
}

sub fetchvalue {      # returns a SINGLE field from the database
    my $table = shift;
    my $column = shift;
    my $param1 = shift;
    my $param1val = shift;
    my @query = $db->selectrow_array("SELECT $column FROM $table WHERE $param1 = '$param1val'");
    return $query[0];
}

sub fetcharray {        # returns MULTIPLE fields from the database
    my $table = shift;
    my $column = shift;
    my $param1 = shift;
    my $param1val = shift;
    my @query = $db->selectrow_array("SELECT $column FROM $table WHERE $param1 = '$param1val'");
    return @query;
}

sub level_challenge {       # automated challenge when a player levels
    my $id = shift;
    if (!$id) {
        my $query = $db->prepare("SELECT playerid FROM gsrpg_players ".
                                 "WHERE online = 1 ORDER BY RANDOM() DESC");
        $query->execute;
        my @online = $query->fetchall_arrayref;
        $id = $online[0][int(rand($query->rows))][0];
        $query->finish;
        return unless $id;
        undef @online;
    }
    my $playerlevel = fetchvalue("gsrpg_players","level","playerid",$id);
    if ($playerlevel < 10) { return unless rand(4) < 1; } 
    my $query = $db->prepare("SELECT playerid FROM gsrpg_players ".
                             "WHERE online = 1 AND playerid != $id ORDER BY RANDOM() DESC");
    $query->execute;
    my @online = $query->fetchall_arrayref;
    my $opp = $online[0][int(rand($query->rows))][0];
    $query->finish;
    return unless $opp;
    my $mysum = itemsum($id);
    my $oppsum = itemsum($opp);
    $mysum = 1 if $mysum == 0;
    $oppsum = 1 if $oppsum == 0;
    my $myroll = int(rand($mysum));
    my $opproll = int(rand($oppsum));
    my $me = fetchvalue("gsrpg_players","username","playerid",$id);
    my $them = fetchvalue("gsrpg_players","username","playerid",$opp);
    my $gain;
    if ($myroll >= $opproll) {
        $gain = int(rand(fetchvalue("gsrpg_players","level","playerid",$opp)/4));
        $gain = 10 if $gain < 10;
        $gain = int(($gain/100)*(fetchvalue("gsrpg_players","next","playerid",$id)-time()));
        chanmsg("$me [$myroll/$mysum] has challenged $them [$opproll/$oppsum] in combat ".
                "and won! ".dur($gain)." is removed from $me\'s clock.");
        $db->do("UPDATE gsrpg_players SET next = next-$gain WHERE playerid = $id");
        chanmsg("$me reaches next level in ".
                dur(fetchvalue("gsrpg_players","next","playerid",$id)-time()).".");
        my @info = fetcharray("gsrpg_players","level,nick","playerid",$id);
        privmsg("You gained ".dur($gain)." towards level ".($info[0]+1)." by winning a random ".
                    "challenge against $them.",$info[1]) if $options{notifymods};
        if (rand(50) < 1) {
            $gain = int(((5 + int(rand(20)))/100)*
                        (fetchvalue("gsrpg_players","next","playerid",$opp)-time()));
            $db->do("UPDATE gsrpg_players SET next=next+$gain WHERE playerid = $opp");
            chanmsg("$me has dealt $them a Critical Strike! ".
                    dur($gain)." is added to $them\'s clock.");
            logmod($opp,'cs',$gain,0);
        }
        logmod($id,'lc',$gain,1);
    }
    else {
        $gain = int(rand(fetchvalue("gsrpg_players","level","playerid",$opp)/7));
        $gain = 10 if $gain < 10;
        $gain = int(($gain/100)*(fetchvalue("gsrpg_players","next","playerid",$id)-time()));
        chanmsg("$me [$myroll/$mysum] has challenged $them [$opproll/$oppsum] in combat ".
                "and lost! ".dur($gain)." is added to $me\'s clock.");
        $db->do("UPDATE gsrpg_players SET next = next+$gain WHERE playerid = $id");
        chanmsg("$me reaches next level in ".
                dur(fetchvalue("gsrpg_players","next","playerid",$id)-time()).".");
        my @info = fetcharray("gsrpg_players","level,nick","playerid",$id);
        privmsg("You lost ".dur($gain)." away from level ".($info[0]+1)." by losing a random ".
                    "challenge against $them.",$info[1]) if $options{notifymods};
        logmod($id,'lc',$gain,0);
    }
}

sub manual_challenge {      # manual challenge, opponent is defined by the player
    my $id = shift;
    my $usernick = shift;
    my $opp = shift or return undef;
    my $mysum = itemsum($id);
    my $oppsum = itemsum($opp);
    $mysum = 1 if $mysum == 0;
    $oppsum = 1 if $oppsum == 0;
    my $myroll = int(rand($mysum+1));
    my $opproll = int(rand($oppsum+1));
    my $me = fetchvalue("gsrpg_players","username","playerid",$id);
    my $them = fetchvalue("gsrpg_players","username","playerid",$opp);
    my $gain;
    if ($mysum <= $oppsum) {
        if ($myroll >= $opproll) {
            $gain = int(((1 - ($mysum/$oppsum))*
                        (fetchvalue("gsrpg_players","next","playerid",$id)-time()))*0.6);
            chanmsg("$me [$myroll/$mysum] has challenged $them [$opproll/$oppsum] in combat ".
                    "and won! ".dur($gain)." is removed from $me\'s clock.");
            $db->do("UPDATE gsrpg_players SET next = next-$gain WHERE playerid = $id");
            chanmsg("$me reaches next level in ".
                    dur(fetchvalue("gsrpg_players","next","playerid",$id)-time()).".");
            my $level = fetchvalue("gsrpg_players","level","playerid",$id)+1;
            privmsg("You gained ".dur($gain)." towards level $level by winning your ".
                    "challenge against $them.",$usernick) if $options{notifymods};
            logmod($id,'mc',$gain,1);
        }
        else {
            $gain = int(((1 - ($mysum/$oppsum))*
                         (fetchvalue("gsrpg_players","next","playerid",$id)-time()))*0.5);
            chanmsg("$me [$myroll/$mysum] has challenged $them [$opproll/$oppsum] in combat and lost! ".
                        dur($gain)." is added to $me\'s clock.");
            $db->do("UPDATE gsrpg_players SET next = next+$gain WHERE playerid = $id");
            chanmsg("$me reaches next level in ".
                    dur(fetchvalue("gsrpg_players","next","playerid",$id)-time()).".");
            my $level = fetchvalue("gsrpg_players","level","playerid",$id)+1;
            privmsg("You lost ".dur($gain)." away from level $level by losing your ".
                    "challenge against $them..",$usernick) if $options{notifymods};
            logmod($id,'mc',$gain,0);
        }
    }
    else {
        if ($myroll >= $opproll) {
            $gain = int((($oppsum/$mysum)*
                         (fetchvalue("gsrpg_players","next","playerid",$id)-time())) * 0.15);
            chanmsg("$me [$myroll/$mysum] has challenged $them [$opproll/$oppsum] in combat and won! ".
                    dur($gain)." is removed from $me\'s clock.");
            $db->do("UPDATE gsrpg_players SET next = next-$gain WHERE playerid = $id");
            chanmsg("$me reaches next level in ".
                    dur(fetchvalue("gsrpg_players","next","playerid",$id)-time()).".");
            my $level = fetchvalue("gsrpg_players","level","playerid",$id)+1;
            privmsg("You gained ".dur($gain)." towards level $level by winning your ".
                    "challenge against $them.",$usernick) if $options{notifymods};
            logmod($id,'mc',$gain,1);
        }
        else {
            $gain = int((($oppsum/$mysum)*
                         (fetchvalue("gsrpg_players","next","playerid",$id)-time())) * 0.12);
            chanmsg("$me [$myroll/$mysum] has challenged $them [$opproll/$oppsum] in combat and lost! ".
                        dur($gain)." is added to $me\'s clock.");
            $db->do("UPDATE gsrpg_players SET next = next+$gain WHERE playerid = $id");
            chanmsg("$me reaches next level in ".
                    dur(fetchvalue("gsrpg_players","next","playerid",$id)-time()).".");
            my $level = fetchvalue("gsrpg_players","level","playerid",$id)+1;
            privmsg("You lost ".dur($gain)." away from level $level by losing your ".
                    "challenge against $them.",$usernick) if $options{notifymods};
            logmod($id,'mc',$gain,0);
        }
    }
    my $times = fetchvalue("gsrpg_players","challenge_times","playerid",$id);
    my $next_time = int((2 + $times)**$options{challengestep});
    privmsg("You must now wait ".dur($next_time)." before you may challenge again.",$usernick);
    $db->do("UPDATE gsrpg_players SET challenge_times=challenge_times+1, ".
            "challenge = ".time()."+$next_time WHERE playerid = $id");
}

sub random_challenge {      # random challenge, bot picks the challengers (by itemsum)
    my $id = shift;
    my $usernick = shift or return undef;
    my @lower_query = $db->selectall_arrayref("SELECT playerid FROM gsrpg_players ".
                        "WHERE itemsum(playerid) < itemsum($id) AND online = 1 ".
                        "ORDER BY itemsum(playerid) DESC LIMIT 1");
    my @upper_query = $db->selectall_arrayref("SELECT playerid FROM gsrpg_players ".
                        "WHERE itemsum(playerid) > itemsum($id) AND online = 1 ".
                        "ORDER BY itemsum(playerid) ASC LIMIT 1");
    my $lower = $lower_query[0][0][0];
    my $upper = $upper_query[0][0][0];
    my $opp = (rand(2) < 1)?$lower:$upper;
    $opp = $lower if !$opp;     # make sure we've picked someone
    $opp = $upper if !$opp;     # make sure we've picked someone
    return unless $opp;
    my $mysum = itemsum($id);
    my $oppsum = itemsum($opp);
    $mysum = 1 if $mysum == 0;
    $oppsum = 1 if $oppsum == 0;
    my $myroll = int(rand($mysum));
    my $opproll = int(rand($oppsum));
    my $me = fetchvalue("gsrpg_players","username","playerid",$id);
    my $them = fetchvalue("gsrpg_players","username","playerid",$opp);
    my $gain;
    if ($myroll >= $opproll) {
        $gain = int(fetchvalue("gsrpg_players","level","playerid",$opp)/5);
        $gain = 7 if $gain < 7;
        $gain = int(($gain/100)*(fetchvalue("gsrpg_players","next","playerid",$id)-time()));
        chanmsg("$me [$myroll/$mysum] has challenged $them [$opproll/$oppsum] in combat and won! ".
                    dur($gain)." is removed from $me\'s clock.");
        $db->do("UPDATE gsrpg_players SET next = next-$gain WHERE playerid = $id");
        chanmsg("$me reaches next level in ".
                dur(fetchvalue("gsrpg_players","next","playerid",$id)-time()).".");
        my $level = fetchvalue("gsrpg_players","level","playerid",$id)+1;
        privmsg("You gained ".dur($gain)." towards level $level by winning your ".
                "challenge against $them.",$usernick) if $options{notifymods};
        logmod($id,'rc',$gain,1);
    }
    else {
        $gain = int(fetchvalue("gsrpg_players","level","playerid",$opp)/6);
        $gain = 7 if $gain < 7;
        $gain = int(($gain/100)*(fetchvalue("gsrpg_players","next","playerid",$id)-time()));
        chanmsg("$me [$myroll/$mysum] has challenged $them [$opproll/$oppsum] in combat and lost! ".
                    dur($gain)." is added to $me\'s clock.");
        $db->do("UPDATE gsrpg_players SET next = next+$gain WHERE playerid = $id");
        chanmsg("$me reaches next level in ".
                dur(fetchvalue("gsrpg_players","next","playerid",$id)-time()).".");
        my $level = fetchvalue("gsrpg_players","level","playerid",$id)+1;
        privmsg("You lost ".dur($gain)." away from level $level by losing your ".
                "challenge against $them.",$usernick) if $options{notifymods};
        logmod($id,'rc',$gain,0);
    }
    my $times = fetchvalue("gsrpg_players","challenge_times","playerid",$id);
    my $next_time = int((2 + $times)**$options{challengestep});
    privmsg("You must now wait ".dur($next_time)." before you may challenge again.",$usernick);
    $db->do("UPDATE gsrpg_players SET challenge_times=challenge_times+1, ".
            "challenge = ".time()."+$next_time WHERE playerid = $id");
}

sub hog {       # the hand of god; can hurt or help
    my $query = $db->prepare("SELECT playerid FROM gsrpg_players ".
                             "WHERE online = 1 ORDER BY RANDOM() DESC");
    $query->execute;
    my @online = $query->fetchall_arrayref;
    my $player = $online[0][int(rand($query->rows))][0];
    $query->finish;
    target_hog($player);
}

sub target_hog {
    my $player = shift or return undef;
    my @info = fetcharray("gsrpg_players","username,level,class,next,nick","playerid",$player);
    my $win = int(rand(5));
    my $time = int(((5 + int(rand(71)))/100) * ($info[3]-time()));
    if ($win) {
        $db->do("UPDATE gsrpg_players SET next = next-$time WHERE playerid = $player");
        chanmsg("Verily I say unto thee, the Heavens have burst forth, and ".
            "the blessed hand of God carried $info[0] ".dur($time).
            " toward level ".($info[1]+1).".");
        privmsg("The Hand of God has blessed your path and carried you ".dur($time).
                " towards level ".($info[1]+1).".",$info[4]) if $options{notifymods};
    }
    else {
        $db->do("UPDATE gsrpg_players SET next = next+$time WHERE playerid = $player");
        chanmsg("Thereupon He stretched out His little finger ".
            "among them and consumed $info[0] with fire, slowing the heathen ".dur($time).
            " from level ".($info[1]+1));
        privmsg("The Hand of God has cursed your journey and pulled you ".dur($time).
                " away from level ".($info[1]+1).".",$info[4]) if $options{notifymods};
    }
    @info = fetcharray("gsrpg_players","username,level,class,next","playerid",$player);
    chanmsg("$info[0] reaches next level in ".dur($info[3]-time()).".");
    logmod($player,'ho',$time,($win)?1:0);
}

sub calamity {      # evil bastards!
    my $query = $db->prepare("SELECT playerid FROM gsrpg_players ".
                             "WHERE online = 1 ORDER BY RANDOM() DESC");
    $query->execute;
    my @online = $query->fetchall_arrayref;
    my $player = $online[0][int(rand($query->rows))][0];
    $query->finish;
    return unless $player;
    my @info = fetcharray("gsrpg_players","username,level,class,next,nick","playerid",$player);
    my $time = int(int(5 + rand(8)) / 100 * ($info[3]-time()));
    my @actions = ("had sex with Dumbledore",
                            "tried internet male enhancement drugs",
                            "got married",
                            "got an uncurable STD",
                            "knocked a girl up",
                            "woke up with a hangover",
                            "got caught by the FBI",
                            "was molested by a priest",
                            "got caught stealing from Harm"
                        );
    my $actioned = $actions[rand @actions];
    chanmsg("$info[0] $actioned. This terrible calamity has slowed them ".dur($time).
            " from level ".($info[1]+1).".");
    privmsg("You $actioned. This terrible calamity has slowed you down ".dur($time).
                " from level ".($info[1]+1).".",$info[4]) if $options{notifymods};
    $db->do("UPDATE gsrpg_players SET next = next+$time WHERE playerid = $player");
    @info = fetcharray("gsrpg_players","username,level,class,next","playerid",$player);
    chanmsg("$info[0] reaches next level in ".dur($info[3]-time()).".");
    logmod($player,'ca',$time,0);
}

sub godsend {       # woo
    my $query = $db->prepare("SELECT playerid FROM gsrpg_players ".
                             "WHERE online = 1 ORDER BY RANDOM() DESC");
    $query->execute;
    my @online = $query->fetchall_arrayref;
    my $player = $online[0][int(rand($query->rows))][0];
    $query->finish;
    return unless $player;
    my @info = fetcharray("gsrpg_players","username,level,class,next,nick","playerid",$player);
    my $time = int(int(5 + rand(8)) / 100 * ($info[3]-time()));
    my @actions = ("acquired access to an OC-192",
                            "got tickets to a Seattle Seahawks football game",
                            "got tickets to a Dallas Cowboys football game",
                            "got tickets to a Dallas Stars hockey game",
                            "had sex with a supermodel",
                            "found a cure for cancer",
                            "won a large lottery jackpot"
                        );
    my $actioned = $actions[rand @actions];
    chanmsg("$info[0] $actioned. This wondrous godsend has accelerated them ".dur($time).
            " towards level ".($info[1]+1).".");
    privmsg("You $actioned. This wondrous godsend has accelerated you ".dur($time).
                " towards level ".($info[1]+1).".",$info[4]) if $options{notifymods};
    $db->do("UPDATE gsrpg_players SET next = next-$time WHERE playerid = $player");
    @info = fetcharray("gsrpg_players","username,level,class,next","playerid",$player);
    chanmsg("$info[0] reaches next level in ".dur($info[3]-time()).".");
    logmod($player,'go',$time,1);
}

sub team_battle {       # selects six random players for battle
    my $query = $db->prepare("SELECT playerid FROM gsrpg_players ".
                             "WHERE online = 1 ORDER BY RANDOM() DESC");
    $query->execute;
    my @online = $query->fetchall_arrayref;
    return unless $query->rows > 5;
    my %players;
    while (scalar(keys %players) <= 6) {
        my $player = $online[0][int(rand($query->rows))][0];
        if (!exists $players{$player}) { $players{$player} = 1; }
        last if scalar keys %players == 6;
    }
    $query->finish;
    my @player = keys %players;
    my $mysum = itemsum($player[0]) + itemsum($player[1]) + itemsum($player[2]);
    my $oppsum = itemsum($player[3]) + itemsum($player[4]) + itemsum($player[5]);
    my $randmyroll = int(rand($mysum));
    my $randopproll = int(rand($oppsum));
    my $gain;
    if ($randmyroll > $randopproll) {
        $gain = int(rand(19));
        $gain = 2 if $gain < 2;
        my $msg = fetchvalue("gsrpg_players","username","playerid",$player[0]).", ".
                fetchvalue("gsrpg_players","username","playerid",$player[1])." and ".
                fetchvalue("gsrpg_players","username","playerid",$player[2]).
                " [$randmyroll/$mysum] have challenged ".
                fetchvalue("gsrpg_players","username","playerid",$player[3]).", ".
                fetchvalue("gsrpg_players","username","playerid",$player[4])." and ".
                fetchvalue("gsrpg_players","username","playerid",$player[5]).
                " [$randopproll/$oppsum] and won! $gain% of their time to level is eliminated.";
        chanmsg($msg);
        # be careful of flooding...
        if ($options{notifymods}) {
            privmsg($msg,fetchvalue("gsrpg_players","nick","playerid",$player[$_])) for (0..2);
        }
        $db->do("UPDATE gsrpg_players SET next=next-ROUND((next-".time().")*(".($gain/100).")) ".
                "WHERE playerid = $player[0] OR playerid = $player[1] OR playerid = $player[2]");
    }
    else {
        $gain = int(rand(13));
        $gain = 2 if $gain < 2;
        my $msg = fetchvalue("gsrpg_players","username","playerid",$player[0]).", ".
                fetchvalue("gsrpg_players","username","playerid",$player[1])." and ".
                fetchvalue("gsrpg_players","username","playerid",$player[2]).
                " [$randmyroll/$mysum] have challenged ".
                fetchvalue("gsrpg_players","username","playerid",$player[3]).", ".
                fetchvalue("gsrpg_players","username","playerid",$player[4])." and ".
                fetchvalue("gsrpg_players","username","playerid",$player[5]).
                " [$randopproll/$oppsum] and lost! $gain% of their time to level is added back.";
        chanmsg($msg);
        # be careful of flooding...
        if ($options{notifymods}) {
            privmsg($msg,fetchvalue("gsrpg_players","nick","playerid",$player[$_])) for (0..2);
        }
        $db->do("UPDATE gsrpg_players SET next=next+ROUND((next-".time().")*(".($gain/100).")) ".
                "WHERE playerid = $player[0] OR playerid = $player[1] OR playerid = $player[2]");
    }
    logmod($player[$_],'tb',fetchvalue("gsrpg_players","ROUND((next-".time().")*(".($gain/100)."))",
                                       "playerid",$player[$_]),($randmyroll>=$randopproll)?1:0) for (0..2);
}

sub quest {     # starts a new quest
    if (! -r 'quests.txt') {
        alog("Could not locate quests.txt. Quests will be disabled.",0);
        $questcheck += 10800;
        return;
    }
    my $query = $db->prepare("SELECT playerid FROM gsrpg_players ".
                             "WHERE online = 1 AND level >= 20 AND (".time()."-lastlogin)>10800 ".
                             "ORDER BY RANDOM() DESC");
    $query->execute;
    my @online = $query->fetchall_arrayref;
    return unless $query->rows > 3;
    my %players;
    while (scalar(keys %players) <= 4) {
        my $player = $online[0][rand($query->rows)][0];
        if (!exists $players{$player}) { $players{$player} = 1; }
        last if scalar keys %players == 4;
    }
    $query->finish;
    @questers = keys %players;
    $questtime = time()+int(21600+rand(21601));
    open(Q,"quests.txt") or return 0;
    while (chomp(my $line = <Q>)) { $quest = $line if rand $. < 1; }
    close Q;
    my @questnames;
    $questnames[$_] = fetchvalue("gsrpg_players","username",
                                 "playerid",$questers[$_]) for (0..$#questers);
    chanmsg(join(", ",@questnames)." have been chosen by the gods to $quest. ".
            "Quest will end in ".dur($questtime-time()).".");
    $questcheck = time();
}

sub questcheck {        # checks the quest when someone is logged out
    my $id = shift or return undef;
    if ($#questers > 1 && length($quest) > 0) {
        for (0..$#questers) {
            if ($questers[$_] eq $id) {
                if ($#questers >= 3) {
                    my @questnames;
                    $questnames[$_] = fetchvalue("gsrpg_players","username",
                                                 "playerid",$questers[$_]) for (0..$#questers);
                    chanmsg(join(", ",@questnames)." were on a quest to $quest, ".
                            "but $questnames[$_] has abandoned the group.");
                    splice(@questers,$_,1);
                    @questnames = '';
                    $questnames[$_] = fetchvalue("gsrpg_players","username",
                                                 "playerid",$questers[$_]) for (0..$#questers);
                    chanmsg(join(", ",@questnames)." will continue on by themselves. ".
                            "Quest completes in ".dur($questtime-time()).".");
                    last;
                }
                else {
                    chanmsg(fetchvalue("gsrpg_players","username","playerid",$id).
                            "'s prudence and self-regard has brought the wrath of ".
                            "the gods upon the realm. All your great wickedness makes ".
                            "you as it were heavy with lead, and to tend downwards ".
                            "with great weight and pressure towards hell. Therefore ".
                            "have you drawn yourselves 15 steps closer to that gaping ".
                            "maw.");
                    undef @questers; $questtime = 0;
                    $questcheck = time();
                }
            }
        }
    }
}

sub itemsum {       # returns a player's itemsum (note: this is PG function, may need changing)
    my $id = shift;
    my @itemsum = $db->selectrow_array("SELECT ITEMSUM('$id')");   # PGSQL created function, woo
    return $itemsum[0];
}

sub fetchitem {     # returns an individual item from the items table
    my $item = shift;
    my $id = shift;
    my @query = $db->selectrow_array("SELECT $item ".
                                     "FROM gsrpg_items WHERE playerid = $id");
    return ($query[0]) ? $query[0] : 0;
}

sub adminlevel {    # returns the admin level of a NICKNAME
    my $nick = shift;
    $nick =~ s/\\/\\\\/g if $nick =~ /\\/;
    my @query = $db->selectrow_array("SELECT admin,online ".
                                     "FROM gsrpg_players WHERE nick = '$nick'");
    return 0 unless $query[1] eq '1';
    return ($query[0] > 0) ? $query[0] : 0;
}

sub penalize {      # adds a penalty to a player
    my $id = shift;
    my $type = shift;
    my $time = shift or return undef;
    return if $type !~ /text|quit|kick|nick|part|logout/;
    $db->do("UPDATE gsrpg_players SET next=next+$time WHERE playerid = $id");
    $db->do("UPDATE gsrpg_penalties SET pen_$type=pen_$type+$time WHERE playerid = $id");
    my @info = fetcharray("gsrpg_players","next,nick","playerid",$id);
    privmsg(dur($time)." added to your timer for $type. ".
            "Next level in ".dur($info[0]-time()).".",$info[1]);
}

sub dur {       # converts an interger into a human-readable duratio
    my $s = shift; $s = 0 if $s < 0;
    return "NA ($s)" if $s !~ /^\d+$/;
    return sprintf("%d day%s, %02d:%02d:%02d",$s/86400,($s == 1)?"":"s",
                   ($s%86400)/3600,($s%3600)/60,($s%60));
}

sub mksalt { join '',('a'..'z','A'..'Z','0'..'9','/','.')[rand 64, rand 64]; } # don't change me

sub logmod {    # adds an entry to player logs
    my $id = shift;
    my $type = shift;
    my $mod = shift;
    my $hh = shift;
    my @info = fetcharray("gsrpg_players","level,next","playerid",$id);
    $db->do("INSERT INTO gsrpg_modifiers ".
            "(playerid,timestamp,type,level,timemod,curnext,mod) ".
            "VALUES ('$id','".time()."','$type','$info[0]','$mod','".($info[1]-time())."','$hh')");
}

sub isunique {      # returns whether an item is unique
    my $id = shift;
    my $item = shift or return undef;
    my $chk = fetchvalue("gsrpg_items","unique_$item","playerid",$id);
    return '' unless $chk;
    return "(".uitems($chk).")";
}

sub uitems {        # list of unique items
    my $item = shift;
    if ($item eq 1) { return "Fugu's Foam-Bat of useless knowledge"; }
    if ($item eq 2) { return "Crad's Ring of Sticky Fingers"; }
    if ($item eq 3) { return "rev's Neutronium Gauntlets of Fortitude"; }
    if ($item eq 4) { return "Shoat's Shower Robe of Cleanliness"; }
    if ($item eq 5) { return "pb's Fuzzy Pink Bunny Slippers"; }
    if ($item eq 6) { return "SailorFrag's Shield of the srvx"; }
    if ($item eq 7) { return "rev's Fury Guard Talisman"; }
    if ($item eq 8) { return "TunkeyMickeT's Great Ring of the Rooster"; }
    if ($item eq 9) { return "kikkoman's Smelly Fish Helmet"; }
    if ($item eq 10) { return "Harm's 95M .50cal Rifle"; }
}

sub checkstr {
    my $str = shift or return undef;
    my $t;
    while (length($str)) {
        $t = substr($str,0,1);
        return 0 if $t !~ /[\w\[\]\(\)\.!\-#\{\}\| `^]/;
        substr($str,0,1) = '';
    }
    return 1;
}

sub daemonize {     # detachs from the controlling terminal and fork()'s
    if ($verbose || $debug) {
        print "Verbose/debug settings override daemonization. I will not detach.\n";
        return;
    }
    use POSIX 'setsid';
    $SIG{CHLD} = 0;
    fork() && exit(0);
    POSIX::setsid() || die("POSIX::setsid() failed: $!");
    $SIG{CHLD} = 0;
    fork() && exit(0);
    $SIG{CHLD} = 0;
    open(STDIN,'/dev/null')
        or alog("Cannot read /dev/null: $!",1);
    open(STDOUT,">>$options{logfile}")
        or alog("Cannot write standard output to $options{logfile}: $!",1);
    open(STDERR,">>$options{logfile}")
        or alog("Cannot write standard errors to $options{logfile}: $!",1);
    if (length($options{pidfile})) {
        open(PID,">$options{pidfile}")
            or alog("Could not open pid file for writing: $!",1);
        print PID $$;
        close PID;
    }
}

sub ts {        # timestamp for logging
    my @ts = localtime(time);
    return sprintf("[%02d/%02d/%02d %02d:%02d:%02d] ",
                   $ts[4]+1,$ts[3],$ts[5]%100,$ts[2],$ts[1],$ts[0]);
}

sub alog {      # write out to the specified logfile, die()'s if mode is 1
    my $msg = shift;
    my $mode = shift;
    die($msg) unless $options{logfile};
    open(B,">>$options{logfile}");
    print B ts()."$msg\n";
    close B;
    die($msg) if $mode == 1;
    return $msg;
}

sub chanlog {       # prints out channel statistics to a remote file
    $chanrec = 0; $bans = 0;
    puttext("LIST $options{botchan}");
    puttext("MODE $options{botchan} +b");
}

sub backup {    # invokes pg_dump to backup the database
    if (! -d ".dbbackup/") { mkdir(".dbbackup",0755); }
    chomp(my $date = `/bin/date +%Y%m%d%H`);
    alog("Could not write to backup file: $!",1)
        if system "pg_dump -f .dbbackup/gsrpg.dump.$date $options{database}";
}

sub showhelp {  # EXTREMELY complicated function here; edit it and you will DIE!$#@
    print "GSRPG v$version
Syntax: $0 [switches]
        
Available Switches:
--help, -h              Prints this message
--debug, -d             Runs gsrpg in debug mode
--verbose, -v           Print status messages
--configfile, -f        Specifies the location of the config file\n";
}
