# Versioning

Releases are versioned according to [semantic versioning](http://semver.org/) rules...

 > Given a version number MAJOR.MINOR.PATCH, increment the:
 >
 > 0. MAJOR version when you make incompatible API changes,
 > 0. MINOR version when you add functionality in a backwards-compatible manner, and
 > 0. PATCH version when you make backwards-compatible bug fixes.

Release version bumps may not reflect upstream version changes. For example, if a dependency goes from 2.3 to 2.4, the release version may only bump the patch if new features are not exposed through the release.

A forward-fixing versioning policy is followed. In general, fixes will not be backported.
