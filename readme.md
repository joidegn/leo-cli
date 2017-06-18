#leo-cli
===================

leo-cli is a command line tool which can be used to translate words or phrases from several languages to german. It uses the open dictionary [dict.leo.org][]. I wrote this because visiting their website, choosing the language, typing the word and clicking the submit button required several too many steps. I am a lazy person.

[dict.leo.org]: http://dict.leo.org



##Installation
===================
This tool requires beatiful soup, the wonderful requests library and the tabulate library.
###install beautifulsoup, requests and tabulate
pip install beautifulsoup4 requests tabulate

###install leo-cli
pip install leo-cli

###update
There has been a layout change on leo.org so you might have to 
pip install leo-cli --upgrade

##usage:
===================
leo example

leo another example

leo "hang out"

leo -l fr bonne gout

leo -l ru книга

leo -l pt ação

leo -i haengen

## TODO
* print non-German plurals
* allow specifying target and source languages separately
* (maybe) don't print conjugation labels in translation header for conjugations
* alternative conjugations with labels for usage (hängen)
* label haupt/nebensätzlich sections for verbs
