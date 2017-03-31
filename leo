#!/usr/bin/env python3

# TODO: alternative conjugations with labels for usage (hängen)
# TODO: label haupt/nebensätzlich sections for verbs
# TODO: allow filtering definitions by POS
# TODO: print POS of definitions
from argparse import ArgumentParser
import requests
import sys
import time

from bs4 import BeautifulSoup
from tabulate import tabulate

COUNTRY_CODES = {'de', 'en', 'fr', 'es', 'pt', 'ru'}
LANGUAGES = {'fr': 'French', 'de': 'German', 'es': 'Spanish', 'en': 'English', 'ru': 'Russian', 'pt': 'Portuguese'}

TRANSLATE_URL = """http://dict.leo.org/dictQuery/m-vocab/%(lang)s/query.xml?tolerMode=nof&lp=%(lang)s&lang=de&rmWords=off&rmSearch=on&search=%(word)s&searchLoc=0&resultOrder=basic&multiwordShowSingle=on"""

FLECTAB_URL = """https://dict.leo.org/dictQuery/m-vocab/ende/stemming.xml"""

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

def flecttab(word, lang, pos):
    entries = _get_entries(word, lang)
    if not entries:
        return
    tables = _get_tables(entries, pos)
    try:
        next_table = next(tables)
    except StopIteration:
        return
    while next_table is not None:
        en, de, table = next_table
        if table.find('verbtab') and pos in ['all', 'v']:
            yield _extract_verb(table, en, de)
        elif table.find('nountab') and pos in ['all', 'n']:
            yield _extract_noun(table, en, de)
        elif table.find('adjtab') and pos in ['all', 'adj']:
            yield _extract_adjective(table, en, de)
        try:
            next_table = next(tables)
            # give the website a break
            time.sleep(3)
        except StopIteration:
            return

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
    return {'name': case_name, 'value': (art.get_text() + ' ' if art else '') + radical + ending}

def _extract_adjective(table, en, de):
    noun = {'type': 'adjective', 'en': en, 'de': de, 'moods': []}
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

def _get_tables(entries, pos):
    keys = set()
    url2en = {}
    url2de = {}
    for entry in entries:
        en = entry.find('side', lang='en').find('word')
        en = en.get_text() if en else ''
        de = entry.find('side', lang='de').find('word')
        de = de.get_text() if de else ''

        sides = entry.find_all('side', lang='de')
        for side in sides:
            flecttab = side.find('flecttab')
            if flecttab:
                if pos:
                    if pos == 'adj' and flecttab['stemType'] != 'adj':
                        continue
                    elif pos == 'v' and flecttab['stemType'] != 'verb':
                        continue
                    elif pos == 'n' and flecttab['stemType'] != 'noun':
                        continue
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

def _print_translations(args):
    translation = translate(args['word'], args['lang'] + 'de')
    if translation is None:
        print('\tno translation found...')
    else:
        print(tabulate(translation, headers=[LANGUAGES[args['lang']], 'German']))

def _print_inflection_tables(args):
    for table in flecttab(args['word'], args['lang'] + 'de', args['pos']):
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
        elif table['type'] == 'adjective':
            for mood in table['moods']:
                print("===" + mood['name'] + "===")
                for variant in mood['variants']:
                    print(variant['name'])
                    print(tabulate(variant['cases']))
        print()


if __name__ == '__main__':
    lang = 'ende'  # language
    parser = ArgumentParser(description='Retrieve word information via the Leo website')
    parser.add_argument("-l", "--lang", dest="lang", default='en',
        choices=COUNTRY_CODES,
        help="source language, 2 chars (e.g. 'en')")
    parser.add_argument("-i", "--inflect",
        action="store_true", dest="inflect", default=False,
        help="print inflection tables for all homonyms; one table is printed every 3 seconds")
    parser.add_argument("-p", "--pos", dest="pos", choices=['all', 'n', 'v', 'adj'],
        default='all',
        help="Part of speech of inflection tables to show.")
    parser.add_argument("-d", "--define",
        action="store_true", dest="define", default=False,
        help="print dictionary definitions")
    parser.add_argument('word')
    args = vars(parser.parse_args())

    if args['define']:
        _print_translations(args)
    if args['inflect']:
        _print_inflection_tables(args)
