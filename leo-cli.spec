%define name leo-cli
%define version 0.4.0
%define unmangled_version %{version}
%define release 1%{?dist}

Summary: leo.org command line tool
Name: %{name}
Version: %{version}
Release: %{release}
Source0: https://pypi.python.org/packages/source/l/leo-cli/%{name}-%{unmangled_version}.tar.gz
License: MIT
Group: Applications/Text
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-buildroot
Prefix: %{_prefix}
BuildArch: noarch
Vendor: Johannes Degn <j@degn.de>
Url: https://github.com/JoiDegn/leo-cli

BuildRequires: python3

%description
leo-cli is a command line tool which can be used to translate words or phrases
from several languages to german. It uses the open dictionary dict.leo.org. I
wrote this because visiting their website, choosing the language, typing the
word and clicking the submit button required several too many steps. I am a lazy
person.

%prep
%setup -n %{name}-%{unmangled_version}

%build
python3 setup.py build

%install
python3 setup.py install -O1 --root=$RPM_BUILD_ROOT --record=INSTALLED_FILES

%clean
rm -rf $RPM_BUILD_ROOT

%files -f INSTALLED_FILES
%defattr(-,root,root)
