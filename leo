#!/usr/bin/env python3

import sys
import requests
from bs4 import BeautifulSoup

COUNTRY_CODES = {'de', 'en', 'fr', 'es'}
LANGUAGES = {'fr': 'French', 'de': 'German', 'es': 'Spanish', 'en': 'English'}

URL = """http://dict.leo.org/dictQuery/m-vocab/ende/query.xml?tolerMode=nof&lp=%(lang)s&lang=de&rmWords=off&rmSearch=on&search=%(word)s&searchLoc=0&resultOrder=basic&multiwordShowSingle=on"""

lang = 'ende'  # language
help_text = """Usage leo [language] phrase1 [phrase2] [phrase3] ...\n\n
    \t language can be one of en, fr, es."""


def translate(word, lang):
    r = requests.get(
        URL % {
            'lang': lang,
            'word': word
        }
    )

    soup = BeautifulSoup(r.text, 'xml')
    results = soup.find_all('entry')
    if results:
        results_translation = [res.find(hc=0).find('word').get_text() for res in results]
        results_origin = [res.find(hc=1).find('word').get_text() for res in results]
        return list(zip(results_origin, results_translation))

if __name__ == '__main__':
    if sys.argv[1] in COUNTRY_CODES:
        lang = sys.argv[1] + 'de'

    phrases = [arg for arg in sys.argv[1:] if arg not in COUNTRY_CODES]

    print ('translating to: %s' % LANGUAGES[sys.argv[1]])
    translations = {word: translate(word, lang) for word in phrases}
    for word in translations:
        if len(translations) > 1:
            print('\n%s:' % word)
        if translations[word]:
            for trans in translations[word]:
                print('%s\t\t%s' % trans)
        else:
            print('\tno translation found...')

