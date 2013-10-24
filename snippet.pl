#!/usr/bin/perl -w
use strict;
use Cwd qw(abs_path);
use File::Basename;
use File::Spec;
use feature 'say';
use feature ':5.10';

# print color text on terminal 
# manual: http://perldoc.perl.org/Term/ANSIColor.html
use Term::ANSIColor;
use Term::ANSIColor qw(:constants);

my $libDir = '/Users/zhenghongwang/Dropbox/PROG/snippet/';

my $debug;

# ==== settings ====
my $AUTO_SHOW_DIR = 1;

# ==== tags for print ====
my $T_AI = "[[o皿o]]\$ "; # tag for interaction
my $T_USER = "(^_^) -> "; # tag for user input 
my $T_CHANGE_DIR = "Current directory is changed to -> ";
my $T_OPEN_FILE_VIM = "Open file by vim -> ";
my $T_COPY_FILE = "Copy file to clipboard -> ";

# ==== commands ====
my $CP = " | ";
my $AVAILABLE_COMMANDS = "Avaiable Commands:";
my $COMMAND_SHOW_DIR = "[S]how directory";
my $COMMAND_OPEN_DIR_OR_FILE = "[O]pen file or directory";
my $COMMAND_QUIT = "[Q]uit";
my $COMMAND_BACK_TO_PARENT = "[B]ack to parent";
my $COMMAND_COPY_CLIPBOARD = "[C]opy";

# ==== error messages ====
my $ERROR_NO_SUCH_FILE_SHORTCUT_EXISTED = "ERROR: No Such file shortcut existed!";
my $ERROR_CANNOT_COPY_DIRECTORY_CLIPBOARD = "ERROR: Cannot copy directory to clipboard!";
my $ERROR_NO_SUCH_COMMAND = "ERROR: No such command!";

# ==== debug messages ====
my $DEBUG_RUNNING_IN_DEBUG_MODE = "DEBUG: RUNNING IN DEBUG MODE";

# running in debug mode?
if (defined($ARGV[0]) && $ARGV[0] eq '-d') {
    $debug = 1;
    &dprint($DEBUG_RUNNING_IN_DEBUG_MODE);
}

opendir curDirHandler , $libDir or die "$!";
my @files = readdir curDirHandler;
closedir curDirHandler;

# build command instructions first
sub ciprint {
    &aiprint($AVAILABLE_COMMANDS);
    my $commandInstructions = '';
    $commandInstructions.=$COMMAND_SHOW_DIR.$CP;
    $commandInstructions.=$COMMAND_OPEN_DIR_OR_FILE.$CP;
    $commandInstructions.=$COMMAND_BACK_TO_PARENT.$CP;
    $commandInstructions.=$COMMAND_COPY_CLIPBOARD.$CP;
    $commandInstructions.=$COMMAND_QUIT;
    &aiprint($commandInstructions);
}

# ==== hash table for shortcuts ====
my %file_hash;

# ==== flags for shortcuts input ====
my $F_waitingShortcutsInput;

# ==== last used command ====
my $gLastUsedCommand = undef;

# interaction start from here
&ciprint;
&generateFileShortcuts;
while(my $command = <STDIN>) {
    chomp($command);
    if ($command ~~ /^S$/i) {
        &handleCommandShowDir($command);
    } elsif ($command ~~ /^Q$/i) {
        &handleCommandQuit;
    } elsif ($command ~~ /^B$/i) {
        &handleCommandBack;
    } elsif ($command ~~ /^O/i) {
        &handleCommandOpenDir($command);
    } elsif ($command ~~ /^C/i) {
        &handleCommandCopy($command);
    } elsif ($F_waitingShortcutsInput) {
        &handleCommandFileShortcuts($command);
    } else {
        &eprint($ERROR_NO_SUCH_COMMAND); 
        &ciprint;
    }
}

# command handlers 
# ===================================================
sub handleCommandShowDir {
    $gLastUsedCommand = $COMMAND_SHOW_DIR;
    &userprint($COMMAND_SHOW_DIR);
    &showDir();
    &ciprint;
}

sub handleCommandQuit {
    $gLastUsedCommand = $COMMAND_QUIT;
    &userprint($COMMAND_QUIT);
    last;
} 

sub handleCommandBack {
    $gLastUsedCommand = $COMMAND_BACK_TO_PARENT;
    &userprint($COMMAND_BACK_TO_PARENT);
    # Get parent directory
    say $libDir = dirname($libDir);
    &ciprint;
}

sub handleCommandOpenDir {
    my $command = $_[0];
    $gLastUsedCommand = $COMMAND_OPEN_DIR_OR_FILE;
    &userprint($COMMAND_OPEN_DIR_OR_FILE);
    if (length($command) > 1) {
        my $fileShortcut = substr($command, 1);
        $fileShortcut =~ tr/[a-z]/[A-Z]/;
        &openByFileShortcut($fileShortcut);
    }
    $F_waitingShortcutsInput = 1;
}

sub handleCommandCopy {
    my $command = $_[0];
    $gLastUsedCommand = $COMMAND_COPY_CLIPBOARD;
    &userprint($COMMAND_COPY_CLIPBOARD);
    if (length($command) > 1) {
        my $fileShortcut = substr($command, 1);
        $fileShortcut =~ tr/[a-z]/[A-Z]/;
        &copyByFileShortcut($fileShortcut);
    }
    $F_waitingShortcutsInput = 1;
}

sub handleCommandFileShortcuts {
    my $fileShortcut = $_[0];
    $fileShortcut =~ tr/[a-z]/[A-Z]/;
    if ($gLastUsedCommand eq $COMMAND_OPEN_DIR_OR_FILE) {
        $F_waitingShortcutsInput = 0;
        &openByFileShortcut($fileShortcut);
    } elsif ($gLastUsedCommand eq $COMMAND_COPY_CLIPBOARD) {
        &copyByFileShortcut($fileShortcut);
    }
    &ciprint;
}

# ===================================================

sub openByFileShortcut {
    my $fileShortcut = $_[0];
    &dprint("file short cut : $fileShortcut");
    unless (exists($file_hash{$fileShortcut})) {
        &eprint($ERROR_NO_SUCH_FILE_SHORTCUT_EXISTED);
        return;
    }
    if (-d $file_hash{$fileShortcut}) {
        &aiprint($T_CHANGE_DIR);
        say $file_hash{$fileShortcut};
        my $nextDir = $file_hash{$fileShortcut};
        if (defined($nextDir)) {
            if (-d $nextDir) {
                $libDir = $nextDir;
            }
        }
        if ($AUTO_SHOW_DIR) {
            &showDir();
        }
    } else {
        system "vim $file_hash{$fileShortcut}";
    }
}

sub copyByFileShortcut {
    my $fileShortcut = $_[0];
    &dprint("file copy : $fileShortcut");
    unless (exists($file_hash{$fileShortcut})) {
        &eprint($ERROR_NO_SUCH_FILE_SHORTCUT_EXISTED);
        return;
    }
    my $pathFileWantCopy = $file_hash{$fileShortcut};
    if (-f $pathFileWantCopy) {
        &aiprint($T_COPY_FILE.$pathFileWantCopy);
        system "cat $pathFileWantCopy | pbcopy";
    } else {
        &eprint($ERROR_CANNOT_COPY_DIRECTORY_CLIPBOARD);
    }
}

# ==================================================

sub generateFileShortcuts {
    my $curDir = $libDir;

    # clear shortcut hash table
    undef %file_hash;

    opendir(my $sdir, $curDir) or die "$!";
    close($sdir);
    while(defined(my $file = readdir($sdir))) {
        next if $file eq '.';
        next if $file eq '..';
        next if $file =~ m#.swp#;
        # Generate full path
        my $fullpath = File::Spec->catfile($curDir, $file);
        my $hashcode = &genHashCode($file);
        $file_hash{$hashcode} = $fullpath;
    }
}

sub showDir {
    my $curDir = $libDir;

    # clear shortcut hash table
    undef %file_hash;

    opendir(my $sdir, $curDir) or die "$!";
    close($sdir);
    while(defined(my $file = readdir($sdir))) {
        next if $file eq '.';
        next if $file eq '..';
        next if $file =~ m#.swp#;
        # Generate full path
        my $fullpath = File::Spec->catfile($curDir, $file);
        my $hashcode = &genHashCode($file);
        $file_hash{$hashcode} = $fullpath;
        if (-f $fullpath) {
        # print colored ['red'], "F| ".$file."\n";
        # print colored ['blue'], "D| ".$file."\n";
            print $file." [$hashcode] "."\n";
        }
        if (-d $file) {
            &colorSay('bold blue', $file." [$hashcode] ");
        }
        if (-S $file) {
            print "S|".$file."\n";
        }
        if (-l $file) {
            print "L|".$file."\n";
        }
        if (-b $file) {
            print "B|".$file."\n";
        }
        if (-c $file) {
            print "C|".$file."\n";
        }
    }
}

sub showRecursiveDir {
    my @params = @_;
    my $curDir = $params[0];
    # stack 
    my @to_visit;

    push (@to_visit, $curDir);
    my $dir = pop(@to_visit);
    opendir(my $dh, $dir) or die "$!";
    my $file;
    while(defined($file = readdir($dh))) {
        next if $file eq '.';
        next if $file eq '..';
        # Should use File::Spec.
        $file = "$dir/$file";
        if (-d $file) {
            push(@to_visit, $file);
        } else {
            say $file;
        }
    }
    closedir($dh);
}

# return current path is file or directory 
sub isFile {
    my $path = $_[0];
    if (-f $path) {
        return 1;
    } else {
        return 0;
    }
}

# return [A-X][A-X] hashcode
sub genHashCode {
    my $hash = 0;
    use integer;
    foreach(split //, shift) {
        $hash = ($hash + 100 * ord($_)) % 523;
    }
    my $a = $hash/23;
    my $b = $hash%23;
    chr($a + 65).chr($b + 65);
}

&colorSay('red', 'red');
&colorSay('bold red', 'bold red');
&colorSay('green', 'green');
&colorSay('bold green', 'bold green');
&colorSay('yellow', 'yellow');
&colorSay('bold yellow', 'bold yellow');
&colorSay('blue', 'blue');
&colorSay('bold blue', 'bold blue');
&colorSay('magenta', 'magenta');
&colorSay('bold magenta', 'bold magenta');
&colorSay('cyan', 'cyan');
&colorSay('bold cyan', 'bold cyan');
&colorSay('white', 'white');
&colorSay('bold white', 'bold white');
&colorSay('black', 'black');
&colorSay('bold black', 'bold black');

# The recognized normal foreground color attributes (colors 0 to 7) are:
# black  red  green  yellow  blue  magenta  cyan  white
#
# The corresponding bright foreground color attributes (colors 8 to 15) are:
# bright_black  bright_red      bright_green  bright_yellow
# bright_blue   bright_magenta  bright_cyan   bright_white
#
# The recognized normal background color attributes (colors 0 to 7) are:
# on_black  on_red      on_green  on yellow
# on_blue   on_magenta  on_cyan   on_white
#
# The recognized bright background color attributes (colors 8 to 15) are:
# on_bright_black  on_bright_red      on_bright_green  on_bright_yellow
# on_bright_blue   on_bright_magenta  on_bright_cyan   on_bright_white
#
# For 256-color terminals, the recognized foreground colors are:
# ansi0 .. ansi15
# grey0 .. grey23
#
# plus rgbRGB for R, G, and B values from 0 to 5, such as rgb000 or rgb515 . Similarly, the recognized background colors are:
# on_ansi0 .. on_ansi15
# on_grey0 .. on_grey23

# call print with colored highlight
sub colorPrint {
    my @params = @_;
    my $color = $params[0];
    my $str = $params[1];
        # print colored ['blue'], "D| ".$file."\n";
     print colored [$color], $str;
}

# call say with colored highlight
sub colorSay {
    my @params = @_;
    my $color = $params[0];
    my $str = $params[1];
    &colorPrint($color, $str."\n");
}

# ai print 
sub aiprint {
    &colorPrint('bold white on_yellow', $T_AI);
    &iprint($_[0]);
}

# user print 
sub userprint {
    &colorPrint('bold white on_green', $T_USER);
    &colorPrint('green', $_[0]);
    print "\n";
}

# verbose
sub vprint {
    &colorPrint('bold black', $_[0]);
    print "\n";
}

# error
sub eprint {
    &colorPrint('white on_red', $_[0]);
    print "";
    print "\n";
}

# debug
sub dprint {
    if ($debug) {
        &colorPrint('bold cyan', $_[0]);
        print "\n";
    }
}

# info 
sub iprint {
    &colorPrint('bold yellow', $_[0]);
    print "\n";
}

# warning
sub wprint {
    &colorPrint('bold magenta', $_[0]);
    print "\n";
}