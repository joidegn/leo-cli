#!/usr/bin/env python

from distutils.core import setup

setup(name='leo-cli',
    version='0.1',
    description='leo.org command line tool',
    author='Johannes Degn',
    author_email='j@degn.de',
    license="MIT",
    url='https://github.com/JoiDegn/leo-cli',
    scripts=['leo'],
    classifiers = [
        "Programming Language :: Python",
        "Programming Language :: Python :: 3",
        "Development Status :: 3 - Alpha",
        "Intended Audience :: Developers",
        "Environment :: Console",
        "Operating System :: OS Independent",
        "License :: OSI Approved :: MIT License",
    ]

)
