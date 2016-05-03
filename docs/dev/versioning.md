title: Versioning
---

Releases are versioned according to [semantic versioning](http://semver.org/) rules...

 > Given a version number MAJOR.MINOR.PATCH, increment the:
 > 
 > 0. MAJOR version when you make incompatible API changes,
 > 0. MINOR version when you add functionality in a backwards-compatible manner, and
 > 0. PATCH version when you make backwards-compatible bug fixes.

While an upstream dependency may bump a major version, this release may not bump a major version unless the impact is expected to be noticeable.

A forward-fixing versioning policy is followed. In general, fixes will not be backported.
