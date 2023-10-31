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

# Fix beautifulsoup4 dependency #29
# https://github.com/joidegn/leo-cli/pull/29
Patch0: leo-cli-git-fix-beautifulsoup4-dependency.patch
# Remove entrypoint main + egg_info from setup.cfg
# https://github.com/joidegn/leo-cli/issues/30
Patch1: leo-cli-remove-main+egg_info.patch


BuildRequires: pyproject-rpm-macros

%py_provides python3-leo-cli

%generate_buildrequires
%pyproject_buildrequires -r


%description
leo-cli is a command line tool which can be used to translate words or phrases
from several languages to german. It uses the open dictionary dict.leo.org. I
wrote this because visiting their website, choosing the language, typing the
word and clicking the submit button required several too many steps. I am a lazy
person.


%prep
%setup -n %{name}-%{unmangled_version}
%patch -P0 -p1
%patch -P1

%build
%pyproject_wheel

%install
%pyproject_install

%clean
rm -rf $RPM_BUILD_ROOT


%files
%defattr(-,root,root)
%{_bindir}/leo
%{python3_sitelib}/leo_cli-%{unmangled_version}.dist-info/
%doc README.md
%license LICENSE.txt
