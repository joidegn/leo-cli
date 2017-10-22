#leo-cli
===================

leo-cli is a command line tool which can be used to translate words or phrases from several languages to german. It uses the open dictionary [dict.leo.org][]. I wrote this because visiting their website, choosing the language, typing the word and clicking the submit button required several too many steps. I am a lazy person.

[dict.leo.org]: http://dict.leo.org



##Installation
===================
This tool requires beatiful soup, the wonderful requests library and the tabulate library.

###install leo-cli
pip install leo-cli

###update
There has been a layout change on leo.org so you might have to 
pip install leo-cli --upgrade

##usage:

    leo -h
    usage: leo [-h] [-l {en,pt,fr,de,es,ru}] [-i] [-p {all,n,v,adj}] [-d] [-v]
               words [words ...]
    Retrieve word information via the Leo website
    positional arguments:
      words                 the words to look up on the LEO website
    optional arguments:
      -h, --help            show this help message and exit
      -l {en,pt,fr,de,es,ru}, --lang {en,pt,fr,de,es,ru}
                            source language, 2 chars (e.g. 'en')
      -i, --inflect         print inflection tables for all homonyms
      -p {all,n,v,adj}, --pos {all,n,v,adj}
                            Part of speech of words to translate/inflect.
      -d, --define          print dictionary definitions. True by default if -i is
                            not specified.
      -v, --verbose         Print debug messages

###Examples

    leo example
    leo another example
    leo "hang out"
    leo -l fr bonne gout
    leo -l ru книга
    leo -l pt ação
    leo -i reden
    leo ii -p n reden

## TODO
* print non-German plurals
* allow specifying target and source languages separately
* (maybe) don't print conjugation labels in translation header for conjugations
* alternative conjugations with labels for usage (hängen)
* label haupt/nebensätzlich sections for verbs
