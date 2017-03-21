#!/usr/bin/env python3

import requests
import sys
import time
from tabulate import tabulate
from bs4 import BeautifulSoup

COUNTRY_CODES = {'de', 'en', 'fr', 'es', 'pt', 'ru'}
LANGUAGES = {'fr': 'French', 'de': 'German', 'es': 'Spanish', 'en': 'English', 'ru': 'Russian', 'pt': 'Portuguese'}

TRANSLATE_URL = """http://dict.leo.org/dictQuery/m-vocab/%(lang)s/query.xml?tolerMode=nof&lp=%(lang)s&lang=de&rmWords=off&rmSearch=on&search=%(word)s&searchLoc=0&resultOrder=basic&multiwordShowSingle=on"""

FLECTAB_URL = """https://dict.leo.org/dictQuery/m-vocab/ende/stemming.xml"""

lang = 'ende'  # language
help_text = """Usage leo [language] phrase1 [phrase2] [phrase3] ...\n\n
    \t language can be one of en, fr, es, pt, ru."""

def translate(word, lang):
    entries = _get_entries(word, lang)
    if not entries:
        return

    parsed_entries = []
    for entry in entries:
        parsed_sides = []
        for side in entry.find_all('side'):
            if side.find('word'):
                word = side.find('word').get_text()
            else:
                continue
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
            parsed_sides.append(word)
        parsed_entries.append(tuple(parsed_sides))

    return parsed_entries

def _get_entries(word, lang):
    r = requests.get(
        TRANSLATE_URL % {
            'lang': lang,
            'word': word
        }
    )
    soup = BeautifulSoup(r.text, 'xml')
    return soup.find_all('entry')

def flecttab(word, lang):
    entries = _get_entries(word, lang)
    if not entries:
        return
    tables = _get_tables(entries)
    for en, de, table in tables:
        if table.find('verbtab'):
            yield _extract_verb(table, en, de)
        elif table.find('nountab'):
            yield _extract_noun(table, en, de)
        # TODO: adjectives
        time.sleep(3)

def _extract_noun(table, en, de):
    noun = {'type': 'noun', 'en': en, 'de': de, 'moods': []}
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
    return {'name': case['cn'], 'value': (art.get_text() + ' ' if art else '') + radical + ending}

def _extract_verb(table, en, de):
    verb = {'type': 'verb', 'en': en, 'de': de, 'moods': []}
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

    final = ''
    if pronouns:
        final += pronouns + " "
    if aux:
        final += (aux.get_text() + " ")
    final += prefixes
    final += "".join([part.get_text() for part in [radical, ending] if part])
    return final

def _get_tables(entries):
    keys = set()
    url2en = {}
    url2de = {}
    for entry in entries:
        en = entry.find('side', lang='en').find('word').get_text()
        de = entry.find('side', lang='de').find('word').get_text()

        sides = entry.find_all('side', lang='de')
        for side in sides:
            flecttab = side.find('flecttab')
            if flecttab:
                url = flecttab['url']
                url2en[url] = en
                url2de[url] = de
                keys.add(url)

    for key in keys:
        r = requests.get(FLECTAB_URL + key)
        table = BeautifulSoup(r.text, 'xml')
        yield (url2en[key], url2de[key], table)

def pairwise(it):
    it = iter(it)
    while True:
        x = next(it)
        y = next(it, None)
        yield x, y

if __name__ == '__main__':
    if len(sys.argv) == 1 or sys.argv[1] == 'help':
        print(help_text)
        sys.exit(0)

    arg_start_pos = 1
    if sys.argv[1] in COUNTRY_CODES:
        lang = sys.argv[1] + 'de'
        arg_start_pos += 1

    phrases = [arg for arg in sys.argv[arg_start_pos:] if arg not in COUNTRY_CODES]

    # TODO: Run translation then conjugation immediately afterwards
    if sys.argv[arg_start_pos] == 'conj':
        for word in phrases:
            for table in flecttab(word, lang):
                print(table['en'] + "/" + table['de'])
                if table['type'] == 'verb':
                    print("Hilfsverb: " + table['aux'])
                    for mood in table['moods']:
                        print("===" + mood['name'] + "===")
                        for x, y in pairwise(mood['tenses']):
                            if y:
                                print(tabulate({x['name']: x['cases'], y['name']: y['cases']}, headers='keys'))
                            else:
                                print(x['name'])
                                print('-' * len(x['name']))
                                print("\n".join(x['cases']))
                elif table['type'] == 'noun':
                    for mood in table['moods']:
                        print("===" + mood['name'] + "===")
                        for x, y in pairwise(mood['variants']):
                            if y:
                                x_string = tabulate(x['cases'])
                                y_string = tabulate(y['cases'])
                                print(tabulate({x['name']: x_string.split("\n"), y['name']: y_string.split("\n")}, headers='keys'))
                            else:
                                print(x['name'])
                                print(tabulate(x['cases']))
                print()
    else:
        translations = {word: translate(word, lang) for word in phrases}
        for word in translations:
            if len(translations) > 1:
                print('\n%s:' % word)
            if translations[word]:
                print(tabulate(translations[word], headers=[LANGUAGES[lang[0:2]], 'German']))
            else:
                print('\tno translation found...')
