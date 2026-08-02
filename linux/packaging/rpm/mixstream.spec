Name: mixstream
Version: 3.4.6
Release: 1%{?dist}
Summary: A modern, media streaming client.
License: GPL-3.0-or-later
URL: https://github.com/alwayszihanx/mixstream
Source0: %{name}-%{version}.tar.xz
BuildArch: x86_64

Requires: gtk3
Requires: mpv-libs
Requires: alsa-lib
Requires: xz-libs

%description
MixStream is a modern media streaming client with plugin-based extension
support, built with Flutter.

%prep
%setup -q

%build
# precompiled bundle, nothing to build

%install
mkdir -p %{buildroot}%{_libdir}/mixstream
cp -a data lib mixstream %{buildroot}%{_libdir}/mixstream/
mkdir -p %{buildroot}%{_datadir}/applications
mkdir -p %{buildroot}%{_datadir}/icons/hicolor/512x512/apps
sed 's|__LIBDIR__|%{_libdir}|' mixstream.desktop > %{buildroot}%{_datadir}/applications/mixstream.desktop
install -m 644 mixstream.png %{buildroot}%{_datadir}/icons/hicolor/512x512/apps/mixstream.png

%files
%{_libdir}/mixstream/
%{_datadir}/applications/mixstream.desktop
%{_datadir}/icons/hicolor/512x512/apps/mixstream.png

%changelog
* Sun Aug 02 2026 alwayszihan <alwayszihan@proton.me> - 3.4.6-1
- Initial packaging.
