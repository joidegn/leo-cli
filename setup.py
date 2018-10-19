#!/usr/bin/env python

from distutils.core import setup

setup(name='leo-cli',
    version='0.3.5',
    description='leo.org command line tool',
    author='Johannes Degn',
    author_email='j@degn.de',
    license="MIT",
    url='https://github.com/JoiDegn/leo-cli',
    scripts=['leo'],
    install_requires=['beautifulsoup4>=4.3.0', 'lxml>=3.0', 'requests>=1.2.3', 'tabulate'],
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
