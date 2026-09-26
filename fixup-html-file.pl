#!/usr/bin/perl

# This is hackish, but I can't figure out how to modify the html output otherwise

my ($arg) = @ARGV;

$didaddbuttons = 0;
$didmathjaxconfig = 0;
$didheadstyleadd = 0;
$didprintwarn = 0;

$isindex = 0;

while($line = <STDIN>)
{
	# no longer needed
	#$line =~ s{<span[^>]*><button id="light-dark-button".*</button></span>}{};

	if ($line =~ m/<title>.*(?:Index|Índice).*<\/title>/i) {
	  	$isindex = 1;
	}
	# This is the redirect page, do not do anything to it
	if ($line =~ m/<meta http-equiv.*refresh.*0; URL=.*>/) {
		print $line;
		while($line = <STDIN>) {
			print $line;
		}
	 	exit 0;
	}
	if ($line =~ m/<a class="index-button.*title="(?:Index|Índice)"/) {
		# Add extra buttons
		$extra = "<a class=\"index-button button\" href=\"https://projetorealmat.github.io/livros/ra/\" title=\"Edição no REALMat\"><span class=\"name\">REALMat</span></a>\n";

		if (not ($line =~ s/<div class="searchbox"/$extra<div class="searchbox"/)) {
			print STDERR "ERROR: Can't add extra buttons!";
			exit 1;
		}
		$didaddbuttons ++;
	}
	if ($line =~ m/<\/script><script.*mathjax\@4\/tex-mml-chtml/) {
		#avoid inline math wrapping, it does awful things
		print "window.MathJax = window.MathJax || {};\n";
  		print "window.MathJax.output = window.MathJax.output || {};\n";
		# it will get scrdolled anyway by our css
  		print "window.MathJax.output.displayOverflow = 'overflow';\n";
  		print "window.MathJax.output.linebreaks = { inline: false };\n";
		$didmathjaxconfig ++;
	}
	if ($line =~ m/<\/head>/) {
		print "<style>\n";
		# Not really critical, avoids flashing some LaTeX code on initial load, as external .css files get loaded slowly
		print " .hidden-content { display:none; }\n";
		# This is for the print PDF warning below
		print " .print-pdf-warning { display:none; }\n";
		print " \@media print { .print-pdf-warning { display:inline; } }\n";
		print "</style>\n";
		$didheadstyleadd ++;
	}
	if ($line =~ m/<\/body>/) {
		print "<p class=\"print-pdf-warning\">\n";
		print " <em>Para uma cópia com qualidade de impressão, acesse a página desta edição no ";
		print "<a href=\"https://projetorealmat.github.io/livros/ra/\">portal REALMat</a>, que oferece o HTML de leitura e o PDF oficial.</em>\n";
		print "</p>\n";
		$didprintwarn ++;
	}
	# no longer there
	#$line =~ s/>Authored in PreTeXt</>Created with PreTeXt</;
	
	# In case chtml is broken again
	# Possibly not correct with move to mathjax 4, so fix before using
	#$line =~ s/^  ["]?chtml["]?: {/  "svg": {/;
	#$line =~ s/tex-chtml[.]js/tex-svg.js/;

	# and upgrade to mathjax4 and use pagella font?
	#$line =~ s/^  ["]?chtml["]?: {/  "svg": {/;
	#$line =~ s/tex-chtml[.]js/tex-svg-nofont.js/;
	#$line =~ s{mathjax\@3/es5}{mathjax\@4};
	#$line =~ s/^window.MathJax = {/window.MathJax = {\n  output: {\n    font: 'mathjax-pagella'\n  },/;

	#print line
	print $line;
}

if (($isindex == 0 && $didaddbuttons != 1) ||
    $didmathjaxconfig != 1 ||
    $didheadstyleadd != 1 ||
    $didprintwarn != 1) {
    print STDERR "ERROR: did not add something!";
    exit 1;
}
