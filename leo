#!/usr/bin/env python

from __future__ import print_function

import sys

user_interrupt_errors = (KeyboardInterrupt,)
if sys.version_info[0] == 3:
    user_interrupt_errors += (BrokenPipeError,)
else:
    user_interrupt_errors += (IOError,)

try:
    from argparse import ArgumentParser
    from collections import defaultdict
    import requests
    import time

    from bs4 import BeautifulSoup
    from tabulate import tabulate
except user_interrupt_errors as error:
    # interrupted by the user
    if __name__ == '__main__':
        exit()
    else:
        raise error

TARGET_LANG = 'de'

COUNTRY_CODES = {'de', 'en', 'fr', 'es', 'pt', 'ru'}
LANGUAGES = {'fr': 'French', 'de': 'German', 'es': 'Spanish', 'en': 'English', 'ru': 'Russian', 'pt': 'Portuguese'}

POS_CLI_TO_LEO = {'v': 'verb', 'n': 'noun', 'adj': 'adjective'}

TRANSLATE_URL = """http://dict.leo.org/dictQuery/m-vocab/%(lang)s/query.xml?tolerMode=nof&lp=%(lang)s&lang=de&rmWords=off&rmSearch=on&search=%(word)s&searchLoc=0&resultOrder=basic&multiwordShowSingle=on"""

FLECTAB_URL = """https://dict.leo.org/dictQuery/m-vocab/ende/stemming.xml"""

class LeoRequestManager:
    def __init__(self):
        self.recentlySent = False
    def get_xml(self, url, verbose=False):
        """Returns soup object (xml parsed with lxml)
        If another request has been sent previously, this pauses for 3 seconds
        before sending this one. This is to be polite to the Leo website (and
        avoid possible banning)."""
        if self.recentlySent:
            if verbose:
                print('Pausing between requests to LEO server...',
                      file=sys.stderr)
            time.sleep(1)
        self.recentlySent = True
        if verbose:
            print('Requesting URL: %s' % url, file=sys.stderr)
        r = requests.get(url)
        soup = BeautifulSoup(r.text, 'lxml')
        return soup

requestManager = LeoRequestManager()

def get_entries(word, source_lang, pos_filter, verbose=False):
    entries = _retrieve_translation_doc(word, source_lang, verbose=verbose).find_all('entry')
    if not entries:
        return

    parsed_entries = []
    for entry in entries:
        category = entry.find('category')
        if category is None:
            pos = pos_filter
        else:
            pos = _validate_pos(pos_filter, category['type'])
            if not pos:
                continue
        parsed_sides = []
        for side in entry.find_all('side'):
            word = side.find('word')
            if word:
                word = word.get_text()
            else:
                continue
            lang = side['lang']
            if side.find('small'):
                forms = side.find_all('small')
                for form in forms:
                    form = " ".join(form.strings)
                    # verb conjugations
                    if "|" in form:
                        form = form.replace("|", "")
                        form = form.strip()
                        word += " (" + form + ")"
                    # noun plurals (German-only)
                    elif "Pl.:" in form:
                        form = form.replace("Pl.:", "")
                        form = form.strip()
                        word += " (" + form + ")"
            flecttab = side.find('flecttab')
            if flecttab:
                inflect_url = flecttab['url']
            else:
                inflect_url = None
            parsed_sides.append({'word': word, 'inflect_url': inflect_url, 'lang': lang})
        parsed_entries.append({'sides': parsed_sides, 'pos': pos})
    return parsed_entries

def _validate_pos(pos_filter, pos):
    # often no clear distinction between adjective and adverb in German
    if pos in ['adjective', 'adjv', 'adverb']:
        pos = 'adjective'
    if pos_filter == 'all' or pos == pos_filter:
        return pos
    return None

def _retrieve_translation_doc(word, source_lang, verbose=False):
    url = TRANSLATE_URL % {
            'lang': source_lang + TARGET_LANG,
            'word': word
        }
    return requestManager.get_xml(url, verbose=verbose)

def inflect(entries, verbose=False):
    if not entries:
        return
    tables = _get_tables(entries, verbose=verbose)
    try:
        next_table = next(tables)
    except StopIteration:
        return
    while next_table is not None:
        translations, table = next_table
        if table.find('verbtab'):
            yield _extract_verb(table, translations)
        elif table.find('nountab'):
            yield _extract_noun(table, translations)
        elif table.find('adjtab'):
            yield _extract_adjective(table, translations)
        try:
            next_table = next(tables)
        except StopIteration:
            return

def _extract_noun(table, translations):
    noun = {'pos': 'noun', 'translations': translations, 'moods': []}
    for mood in table.find_all('mood'):
        mood_struct = {'name': mood['title'], 'variants': []}
        for variant in mood.find_all('variant'):
            if variant['title'] == '':
                continue
            variant_struct = {'name': variant['title'], 'cases': []}
            for case in variant.find_all('case'):
                if not case.has_attr('cn'):
                    continue
                variant_struct['cases'].append(_format_noun_case(case))
            mood_struct['variants'].append(variant_struct)
        noun['moods'].append(mood_struct)

    return noun

def _format_noun_case(case):
    case_name = case['cn']
    final = ""
    art = case.find('art')
    radical = case.find('radical')
    radical = radical.get_text() if radical else ''
    ending = case.find('ending').get_text()
    return {'name': case_name, 'value': (art.get_text() + ' ' if art else '') + radical + ending}

def _extract_adjective(table, translations):
    noun = {'pos': 'adjective', 'translations': translations, 'moods': []}
    for mood in table.find_all('mood'):
        mood_struct = {'name': mood['title'], 'variants': []}
        for variant in mood.find_all('variant'):
            if variant['title'] == '':
                continue
            variant_struct = {'name': variant['title'], 'cases': []}
            for case in variant.find_all('case'):
                if not case.has_attr('cn') or case['cn'] == 'NA':
                    continue
                variant_struct['cases'].append(_format_adjective_case(case))
            if variant_struct['cases']:
                mood_struct['variants'].append(variant_struct)
        noun['moods'].append(mood_struct)

    return noun

def _format_adjective_case(case):
    case_name = case['cn']
    final = ""
    radical = case.find('radical')
    radical = radical.get_text() if radical else ''
    adj = case.find('adj')
    arts = adj.find_all('art')
    if len(arts) > 1:
        return _format_multiple_adjective_cases(case_name, radical, adj)

    art = adj.find('art')
    art = art.get_text() if art else None
    part = adj.find('part')
    part = part.get_text() if part else None
    ending = adj.find('ending').get_text()

    return {'name': case_name, 'value': (art + ' ' if art else '') + (part + ' ' if part else '') + radical + ending}

def _format_multiple_adjective_cases(case_name, radical, adj):
    arts = adj.find_all('art')
    endings = adj.find_all('ending')
    gender_arts = dict()
    for art in arts:
        gender_arts[art['g']] = art.get_text()
    gender_endings = dict()
    for ending in endings:
        gender_endings[ending['g']] = ending.get_text()

    cases = []
    for gender in ['sm', 'sf', 'sn']:
        cases.append("%s %s%s" % (gender_arts[gender], radical, gender_endings[gender]))

    return {'name': case_name, 'value': "/".join(cases)}

def _extract_verb(table, translations):
    verb = {'pos': 'verb', 'translations': translations, 'moods': []}
    aux = table.find('auxiliary')
    if aux:
        verb['aux'] = aux.get_text().strip()
    for mood in table.find_all('mood'):
        mood_name = mood['title']
        mood_struct = {'name': mood_name, 'tenses': []}
        verb['moods'].append(mood_struct)
        for tense in mood.find_all('tense'):
            if not tense.has_attr('title'):
                continue
            tense_struct = {'name': tense['title'], 'cases': []}
            mood_struct['tenses'].append(tense_struct)
            for case in tense.find_all("case"):
                tense_struct['cases'].append(_format_verb_case(case))
    return verb

def _format_verb_case(case):
    pronouns = "/".join([ppron.get_text() for ppron in case.find_all("ppron")])
    aux = case.find("aux")
    prefixes = case.find_all("pref")
    if prefixes:
        prefixes = "".join(prefix.get_text() for prefix in prefixes)
    else:
        prefixes = ""
    radical = case.find("radical")
    ending = case.find("ending")
    spref = case.find("spref")

    final = ''
    if pronouns:
        final += pronouns + " "
    if aux:
        final += (aux.get_text() + " ")
    final += prefixes
    final += "".join([part.get_text() for part in [radical, ending] if part])
    if spref:
        final += " " + spref.get_text()
    return final

def _get_tables(entries, verbose=False):
    url2translations = {}
    langs = set()
    for entry in entries:
        target_side = next((side for side in entry['sides'] if side["lang"] == TARGET_LANG))
        url = target_side['inflect_url']
        if url is None or url in url2translations:
            continue
        translations = [side['word'] for side in entry['sides']]
        url2translations[url] = translations

    for url, translations in url2translations.items():
        table_url = FLECTAB_URL + url
        table = requestManager.get_xml(table_url, verbose=verbose)
        yield (translations, table)

def _pairwise(it):
    it = iter(it)
    while True:
        x = next(it)
        y = next(it, None)
        yield x, y

def _print_translation(translation):
    word_table = []
    for entry in translation:
        word_table.append([side['word'] for side in entry['sides']])
    print(tabulate(word_table, headers=[LANGUAGES[args['source_lang']], 'German']))

def _print_inflection_table(table):
    print("/".join(table['translations']))
    print(table['pos'].title())
    if table['pos'] == 'verb':
        print("Hilfsverb: " + table['aux'])
        for mood in table['moods']:
            print("===" + mood['name'] + "===")
            for x, y in _pairwise(mood['tenses']):
                if y:
                    print(tabulate({x['name']: x['cases'], y['name']: y['cases']}, headers='keys'))
                else:
                    print(x['name'])
                    print('-' * len(x['name']))
                    print("\n".join(x['cases']))
    elif table['pos'] == 'noun':
        for mood in table['moods']:
            print("===" + mood['name'] + "===")
            for x, y in _pairwise(mood['variants']):
                if y:
                    x_string = tabulate(x['cases'])
                    y_string = tabulate(y['cases'])
                    print(tabulate({x['name']: x_string.split("\n"), y['name']: y_string.split("\n")}, headers='keys'))
                else:
                    print(x['name'])
                    print(tabulate(x['cases']))
    elif table['pos'] == 'adjective':
        for mood in table['moods']:
            print("===" + mood['name'] + "===")
            for variant in mood['variants']:
                print(variant['name'])
                print(tabulate(variant['cases']))

if __name__ == '__main__':
    lang = 'ende'  # language
    parser = ArgumentParser(description='Retrieve word information via the Leo website')
    parser.add_argument('words', nargs='+', help="the words to look up on the LEO website")
    parser.add_argument("-l", "--lang", dest="source_lang", default='en',
        choices=COUNTRY_CODES,
        help="source language, 2 chars (e.g. 'en')")
    parser.add_argument("-i", "--inflect",
        action="store_true", dest="inflect", default=False,
        help="print inflection tables for all homonyms")
    parser.add_argument("-p", "--pos", dest="pos", choices=['all', 'n', 'v', 'adj'],
        default='all',
        help="Part of speech of words to translate/inflect.")
    parser.add_argument("-d", "--define",
        action="store_true", dest="define", default=False,
        help="print dictionary definitions. True by default if -i is not specified.")
    parser.add_argument("-v", "--verbose",
        action="store_true", dest="verbose", default=False, help="Print debug messages")
    args = vars(parser.parse_args())

    if not args['inflect']:
        args['define'] = True

    if args['pos']:
        args['pos'] = POS_CLI_TO_LEO[args['pos']] if args['pos'] in POS_CLI_TO_LEO else args['pos']

    try:
        if args['define']:
            for word in args['words']:
                entries = get_entries(word, args['source_lang'], args['pos'], verbose=args['verbose'])
                if entries is not None:
                    _print_translation(entries)
                else:
                    print('\tNo translations found')
                if args['inflect']:
                    print()
                sys.stdout.flush()
        if args['inflect']:
            for word in args['words']:
                entries = get_entries(word, args['source_lang'], args['pos'], verbose=args['verbose'])
                tables = inflect(entries, verbose=args['verbose'])

                table_count = 0
                for table in tables:
                    table_count += 1
                    _print_inflection_table(table)
                    print()
                    sys.stdout.flush()
                if table_count == 0:
                    print("\tNo inflection tables found for " + word)
    except user_interrupt_errors as error:
        if args['verbose']:
            print("Interrupted by user", file=sys.stderr)
            exit()
