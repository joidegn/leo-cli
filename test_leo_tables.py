"""Tests for inflection-table lookup in the leo CLI (single-file script)."""

from importlib.machinery import SourceFileLoader
from pathlib import Path

import pytest

leo = SourceFileLoader("leo", str(Path(__file__).resolve().parent / "leo")).load_module()


def test_get_tables_skips_entry_without_german_side():
    entries = [{"sides": [], "pos": "noun"}]
    assert list(leo._get_tables(entries, verbose=False)) == []


def test_get_tables_skips_entry_with_only_source_side():
    entries = [{"sides": [{"word": "hello", "inflect_url": None, "lang": "en"}], "pos": "noun"}]
    assert list(leo._get_tables(entries, verbose=False)) == []


def test_get_tables_skips_entry_with_missing_inflect_url(monkeypatch):
    calls = []
    monkeypatch.setattr(leo.requestManager, "get_xml", lambda url, verbose=False: calls.append(url))
    entries = [{"sides": [{"word": "hallo", "inflect_url": None, "lang": "de"}], "pos": "noun"}]
    assert list(leo._get_tables(entries, verbose=False)) == []
    assert calls == []


def test_get_tables_still_fetches_german_side(monkeypatch):
    seen = []
    monkeypatch.setattr(
        leo.requestManager, "get_xml", lambda url, verbose=False: seen.append(url) or "TABLE"
    )
    entries = [
        {
            "sides": [
                {"word": "house", "inflect_url": None, "lang": "en"},
                {"word": "Haus", "inflect_url": "/stemming/x", "lang": "de"},
            ],
            "pos": "noun",
        }
    ]
    assert list(leo._get_tables(entries, verbose=False)) == [(["house", "Haus"], "TABLE")]
    assert seen == [leo.FLECTAB_URL + "/stemming/x"]
