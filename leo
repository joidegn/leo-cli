#!/usr/bin/env python3

import sys
import requests
from bs4 import BeautifulSoup

COUNTRY_CODES = ['de', 'en', 'fr', 'es']
URL = """http://dict.leo.org/ende?lp=ende&searchLoc=0&cmpType=relaxed&sectHdr=on&lang=%(lang)s&spellToler=&search=%(word)s"""

lang = 'en'  # language
help_text = """Usage leo [language] phrase1 [phrase2] [phrase3] ...\n\n
    \t language can be one of en, fr, es."""

def translate(word, lang):
    r = requests.get(
        URL % {
            'lang': lang,
            'word': word
        }
    )
    soup = BeautifulSoup(r.text)
    results = soup.find(id='results')
    if results:
        trs = results.find_all('tr', valign='top')
        results_origin = [tr.find_all('td')[1].get_text() for tr in trs]
        results_translation = [tr.find_all('td')[3].get_text() for tr in trs]
        return list(zip(results_origin, results_translation))

if sys.argv[1] in COUNTRY_CODES:
    lang = sys.argv[1]

phrases = [arg for arg in sys.argv[1:] if arg not in COUNTRY_CODES]

translations = {word: translate(word, lang) for word in phrases}
for word in translations:
    if len(translations) > 1:
        print('%s:' % word)
    if translations[word]:
        for trans in translations[word]:
            print('%s\t\t%s' % trans)
    else:
        print('\tno translation found...')
