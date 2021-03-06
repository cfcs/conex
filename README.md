## Conex - establish trust in community repositories

%%VERSION%%

[Conex](https://github.com/hannesm/conex) is a library to verify and attest release integrity and
authenticity of a community repository through the use of cryptographic signatures.

NOTE: This is still work in progress, to be deployed with opam 2.0 and the [opam
repository](https://github.com/ocaml/opam-repository).  A [getting started
with conex article](https://hannes.nqsb.io/Posts/Conex) is online.

![screenshot](https://berlin.ccc.de/~hannes/conex.png)

Packages are collected in a community repository to provide an index and
allowing cross-references.  Authors submit their packages to the repository. which
is curated by a team of janitors.  Information
about a package stored in a repository includes: license, author, releases,
their dependencies, build instructions, url, tarball checksum.  When someone
publishes a new package, the janitors integrate it into the repository, if it
compiles and passes some validity checks.  For example, its name must not be misleading,
nor may it be too general.

Janitors keep an eye on the repository and fix emergent failures.  A new
compiler release, or a release of a package on which other packages depend, might break the compilation of
a package.  Janitors usually fix these problems by adding a patch to the build script, or introducing
a version constraint in the repository.

*Conex* ensures that every release of each package has been approved by its author or a quorum of janitors.
A conex-aware client initially verifies the repository using janitor key fingerprints as anchor.
Afterwards, the on-disk repository is trusted, and every update is verified (as a patch) individually.
This incremental verification is accomplished by ensuring all resources
that the patch modifies result in a valid repository with
sufficient approvals.  Additionally, monotonicity is preserved by
embedding counters in each resource, and enforcing a counter
increment after modification.
This mechanism avoids rollback attacks, when an
attacker presents you an old version of the repository.

Opam2 has support for a [`repository validation
command`](http://opam.ocaml.org/doc/2.0/Manual.html#configfield-repository-validation-command)
which `conex_verify` is supposed to be in the future.

A timestamping service (NYI) will periodically approve a global view of the
verified repository, together with a timestamp.  This is then used by the client
to prevent mix-and-match attacks, where an attacker mixes some old packages and
some new ones.  Also, the client is able to detect freeze attacks, since at
least every day there should be a new signature done by the timestamping service.

The trust is rooted in digital signatures by package authors.  The server which
hosts the repository does not need to be trusted.  Neither does the host serving
release tarballs.

If a single janitor would be powerful enough to approve a key for any author,
compromising one janitor would be sufficient to enroll any new identities,
modify dependencies, build scripts, etc.  In conex, a quorum of janitors (let's
say 3) have to approve such changes.  This is different from current workflows,
where a single janitor with access to the repository can merge fixes.

Conex adds metadata, in form of resources, to the repository to ensure integrity and
authenticity.  There are different kinds of resources:

- *Authors*, consisting of a unique identifier, public key(s), accounts.
- *Teams*, sharing the same namespace as authors, containing a set of members.
- *Authorisation*, one for each package, describing which identities are authorised for the package.
- *Package index*, for each package, listing all releases.
- *Release*, for each release, listing checksums of all data files.

Modifications to identities and authorisations need to be approved by a quorum
of janitors, package index and release files can be modified either by an authorised
id or by a quorum of janitors.

## Documentation

[API documentation](https://hannesm.github.io/conex/doc/) is
available online, also a [coverage
report](https://hannesm.github.io/conex/coverage/).

We presented an [abstract at OCaml
2016](https://github.com/hannesm/conex-paper/raw/master/paper.pdf) about an
earlier design.

Another article on an [earlier design (from
2015)](http://opam.ocaml.org/blog/Signing-the-opam-repository/) is also
available.

Conex is inspired by [the update
framework](https://theupdateframework.github.io/), especially on their [CCS 2010
paper](https://isis.poly.edu/~jcappos/papers/samuel_tuf_ccs_2010.pdf), and
adapted to the opam repository.

The [TUF
spec](https://github.com/theupdateframework/tuf/blob/develop/docs/tuf-spec.txt)
has a good overview of attacks and threat model, both of which are shared by conex.

## Installation

`opam instal conex` will install this library and tool,
once you have installed OCaml (>= 4.03.0) and opam (>= 2.0.0beta).

A small test repository with two janitors (their private keys), an empty package
`foo` owned by `c` and valid signatures is
[here](https://github.com/hannesm/testrepo) including transcripts of how it was
setup, and how to setup opams `repo validation hook`.
