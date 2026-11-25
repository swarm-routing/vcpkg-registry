#!/usr/bin/env python3
# Copyright (c) 2026 Daniel Joppi (https://github.com/swarm-routing)
# SPDX-License-Identifier: MIT OR GPL-2.0-only
"""Render a port bump from a published release, and check the versions database.

    port_bump.py bump --port NAME --tag vX.Y.Z [--root DIR] [--base-url URL]
    port_bump.py refresh --port NAME [--root DIR] [--base-url URL]
    port_bump.py check [--root DIR]
    port_bump.py --self-test

bump: the release asset's URL is the port's own (`URLS` in
ports/<port>/portfile.cmake, `${VERSION}` replaced by the tag's version), so
the portfile stays the one source of where a port comes from. The asset is
downloaded, its SHA-256 checked against the release's `SHA256SUMS` (next to
it), and its SHA-512 written into the portfile (`SHA512 <hex>`); the version
goes into vcpkg.json (its `port-version` dropped), the port's git-tree is
computed by git from the files as written (a temporary index: the caller's
index is left alone), and versions/<c>-/<port>.json (newest first) and
versions/baseline.json are updated. A port not in ports/ yet is first copied
from templates/<port>/, so a library's first release needs no hand step.
Nothing is typed: every hash comes from the asset or from git. Run it at the
root of a checkout of this repository; the release automation
(swarm-routing/.github reusable-release.yml, `vcpkg-ports`) runs exactly this,
then commits and opens the PR.

The port's description is its upstream repository's GitHub description
(declared as code in that repository's `[settings] description`), read at
each bump; `refresh` re-reads it between releases and records a change as
the next port-version.

check: every port's vcpkg.json version is the baseline's, and its versions
file records that version with the git-tree of ports/<port> as it is in the
working tree (so run it before committing too); no port is both in ports/
and templates/. vcpkg's own `x-ci-verify-versions` checks the committed
history in CI; this check needs only git and Python.

A release that is not a GitHub release (ns-3's tarball on nsnam.org) is
declared in the portfile by two comment lines: `# RELEASE_TAG ns-${VERSION}`,
the tag's form (the default is `v${VERSION}`, X.Y.Z), and `# CHECKSUM_PAGE
<url>`, the release's own page that lists the asset's SHA-256 or SHA-1
(`${VERSION}` and `${VERSION_DASHED}`, 3.49 as 3-49, in it are replaced). The
asset's digest must appear on that page; the port keeps its own description,
as there is no GitHub repository to read it from.

`--base-url` replaces `https://github.com/` in a GitHub asset URL, and
`https://` in any other (the self-test serves a file:// release tree).
Stdlib only, Python 3.10+.
"""

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.request

VERSION_KEYS = ("version-semver", "version", "version-date", "version-string")
URLS_RE = re.compile(r'URLS\s+"([^"]+)"')
SHA512_RE = re.compile(r"^(\s*SHA512\s+)([0-9a-fA-F]+)\s*$", re.MULTILINE)
RELEASE_TAG_RE = re.compile(r"^#\s*RELEASE_TAG\s+(\S+)\s*$", re.MULTILINE)
CHECKSUM_PAGE_RE = re.compile(r"^#\s*CHECKSUM_PAGE\s+(\S+)\s*$", re.MULTILINE)
GITHUB = "https://github.com/"


class Failure(SystemExit):
    def __init__(self, msg):
        super().__init__(f"port_bump: {msg}")


def read_text(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def read_json(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def write_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")


def version_key(manifest):
    keys = [k for k in VERSION_KEYS if k in manifest]
    if len(keys) != 1:
        raise Failure(
            f"{manifest.get('name')}: exactly one of {', '.join(VERSION_KEYS)} expected"
        )
    return keys[0]


def versions_file(root, port):
    return os.path.join(root, "versions", f"{port[0]}-", f"{port}.json")


def git(root, *args, env=None):
    r = subprocess.run(
        ["git", *args], cwd=root, env=env, capture_output=True, text=True, check=False
    )
    if r.returncode:
        raise Failure(f"git {' '.join(args)}: {r.stderr.strip()}")
    return r.stdout.strip()


def git_tree(root, port):
    """The git-tree of ports/<port> as it is in the working tree, through a
    temporary index (the caller's index and HEAD are untouched)."""
    with tempfile.TemporaryDirectory() as tmp:
        env = dict(os.environ, GIT_INDEX_FILE=os.path.join(tmp, "index"))
        git(root, "add", "--", f"ports/{port}", env=env)
        return git(root, "write-tree", f"--prefix=ports/{port}/", env=env)


def fetch(url):
    try:
        with urllib.request.urlopen(
            url, timeout=120
        ) as r:  # https, or the self-test's file://
            return r.read()
    except OSError as e:
        raise Failure(f"cannot download {url}: {e}") from None


def release_sha256(url, name):
    """The asset's sha256 as its release lists it: the release's SHA256SUMS
    (swarm-routing/.github reusable-release.yml), else the asset's own
    `<asset>.sha256` (AntHocNet's release workflow)."""
    base = url.rsplit("/", 1)[0]
    try:
        sums = fetch(base + "/SHA256SUMS").decode()
    except Failure:
        try:
            sums = fetch(url + ".sha256").decode()
        except Failure:
            raise Failure(
                f"{name}: the release has neither SHA256SUMS nor {name}.sha256"
            ) from None
        first = sums.split()
        return first[0] if first else None
    listed = {
        ln.split()[1].lstrip("*"): ln.split()[0]
        for ln in sums.splitlines()
        if ln.strip()
    }
    return listed.get(name)


def tag_version(portfile_text, tag):
    """The version a release tag names, by the port's RELEASE_TAG form
    (default `v${VERSION}`, X.Y.Z; a declared form also takes X.Y)."""
    m = RELEASE_TAG_RE.search(portfile_text)
    form = m.group(1) if m else "v${VERSION}"
    ver = r"(\d+\.\d+(?:\.\d+)?)" if m else r"(\d+\.\d+\.\d+)"
    rx = re.escape(form).replace(re.escape("${VERSION}"), ver)
    hit = re.fullmatch(rx, tag)
    if not hit:
        shown = "vX.Y.Z" if not m else form.replace("${VERSION}", "X.Y")
        raise Failure(f"{tag}: a release tag is {shown}")
    return hit.group(1)


def rebase(url, base_url):
    """The URL served under --base-url (the self-test's file:// tree)."""
    if not base_url:
        return url
    if url.startswith(GITHUB):
        return url.replace(GITHUB, base_url.rstrip("/") + "/", 1)
    return url.replace("https://", base_url.rstrip("/") + "/", 1)


def asset_url(portfile_text, version, base_url):
    m = URLS_RE.search(portfile_text)
    if not m:
        raise Failure('portfile.cmake: no URLS "..." line')
    return rebase(m.group(1).replace("${VERSION}", version), base_url)


def is_github(portfile_text):
    m = URLS_RE.search(portfile_text)
    return bool(m) and m.group(1).startswith(GITHUB)


def check_listed(portfile_text, version, url, name, asset, base_url):
    """The asset is the one its release lists: SHA256SUMS (or <asset>.sha256)
    for a GitHub release, the CHECKSUM_PAGE's SHA-256 or SHA-1 otherwise."""
    m = CHECKSUM_PAGE_RE.search(portfile_text)
    if not m:
        if release_sha256(url, name) != hashlib.sha256(asset).hexdigest():
            raise Failure(f"{name}: its sha256 is not the one the release lists")
        return
    page_url = (
        m.group(1)
        .replace("${VERSION_DASHED}", version.replace(".", "-"))
        .replace("${VERSION}", version)
    )
    page = fetch(rebase(page_url, base_url)).decode("utf-8", "replace").lower()
    digests = (hashlib.sha256(asset).hexdigest(), hashlib.sha1(asset).hexdigest())
    if not any(re.search(rf"\b{d}\b", page) for d in digests):
        raise Failure(f"{name}: neither its sha256 nor its sha1 is on {page_url}")


def upstream_description(url, base_url=""):
    """The description of the repository the release asset comes from: its
    GitHub description, which swarm-routing declares as code
    (`[settings] description` in that repository's .github/org-sync.toml), so
    a port's description is never typed here and cannot go stale."""
    m = re.match(
        r"^(?:https://github\.com|"
        + re.escape(base_url.rstrip("/") or "-")
        + r")/([^/]+)/([^/]+)/",
        url,
    )
    if not m:
        raise Failure(f"{url}: not a GitHub release asset URL")
    api = (base_url.rstrip("/") + "/api") if base_url else "https://api.github.com"
    req = urllib.request.Request(
        f"{api}/repos/{m.group(1)}/{m.group(2)}",
        headers={"Accept": "application/vnd.github+json"},
    )
    token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
    if token and not base_url:
        req.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(
            req, timeout=60
        ) as r:  # https, or the self-test's file://
            desc = json.load(r).get("description") or ""
    except (OSError, ValueError) as e:
        raise Failure(
            f"cannot read {m.group(1)}/{m.group(2)}'s description: {e}"
        ) from None
    if not desc.strip():
        raise Failure(f"{m.group(1)}/{m.group(2)} has no description")
    return desc.strip()


def bump(root, port, tag, base_url=""):
    pdir = os.path.join(root, "ports", port)
    tdir = os.path.join(root, "templates", port)
    created = not os.path.isdir(pdir)
    src = tdir if created else pdir
    if not os.path.isdir(src):
        raise Failure(f"no ports/{port} and no templates/{port}")
    # Everything is validated before anything is written: the release, and
    # that this version is not already recorded at a later port-version.
    text = read_text(os.path.join(src, "portfile.cmake"))
    version = tag_version(text, tag)
    manifest = read_json(os.path.join(src, "vcpkg.json"))
    key = version_key(manifest)
    if key == "version-semver" and not re.fullmatch(r"\d+\.\d+\.\d+", version):
        raise Failure(f"{port}: version-semver needs X.Y.Z, not {version}")
    vpath = versions_file(root, port)
    db = read_json(vpath) if os.path.exists(vpath) else {"versions": []}
    later = [
        v for v in db["versions"] if v.get(key) == version and v.get("port-version", 0)
    ]
    if later:
        raise Failure(
            f"{port} {version} is already recorded at port-version "
            f"{max(v['port-version'] for v in later)}; a bump to the same release would reset it"
        )
    if not is_github(text) and not CHECKSUM_PAGE_RE.search(text):
        raise Failure(f"{port}: not a GitHub release and no # CHECKSUM_PAGE line")
    url = asset_url(text, version, base_url)
    asset = fetch(url)
    name = url.rsplit("/", 1)[1]
    check_listed(text, version, url, name, asset, base_url)
    if not SHA512_RE.search(text):
        raise Failure("portfile.cmake: no SHA512 line")
    text = SHA512_RE.sub(
        lambda m: m.group(1) + hashlib.sha512(asset).hexdigest(), text, count=1
    )
    manifest[key] = version
    manifest.pop("port-version", None)
    if is_github(text):
        manifest["description"] = upstream_description(url, base_url)
    elif not str(manifest.get("description", "")).strip():
        raise Failure(
            f"{port}: not a GitHub release, so vcpkg.json keeps a description"
        )

    # Written now; undone if the recorded tree for this version disagrees.
    old = {}
    if created:
        shutil.copytree(tdir, pdir)
    else:
        old = {
            f: read_text(os.path.join(pdir, f))
            for f in ("portfile.cmake", "vcpkg.json")
        }
    with open(os.path.join(pdir, "portfile.cmake"), "w", encoding="utf-8") as f:
        f.write(text)
    write_json(os.path.join(pdir, "vcpkg.json"), manifest)
    tree = git_tree(root, port)
    for v in db["versions"]:
        if v.get(key) == version and v["git-tree"] != tree:
            if created:
                shutil.rmtree(pdir)
            for f, body in old.items():
                with open(os.path.join(pdir, f), "w", encoding="utf-8") as out:
                    out.write(body)
            raise Failure(
                f"{port} {version} is already recorded with another git-tree "
                f"({v['git-tree']}); a port change at the same version needs a port-version"
            )
    if created:
        shutil.rmtree(tdir)

    if not any(v.get(key) == version for v in db["versions"]):
        db["versions"].insert(0, {key: version, "port-version": 0, "git-tree": tree})
    write_json(vpath, db)
    bpath = os.path.join(root, "versions", "baseline.json")
    base = read_json(bpath) if os.path.exists(bpath) else {"default": {}}
    base["default"][port] = {"baseline": version, "port-version": 0}
    base["default"] = dict(sorted(base["default"].items()))
    write_json(bpath, base)
    sha512 = hashlib.sha512(asset).hexdigest()
    print(
        f"port_bump: {port} {version}{' (new port, from templates/)' if created else ''}: "
        f"{name} sha512 {sha512[:16]}..., git-tree {tree}",
        file=sys.stderr,
    )
    return {
        "port": port,
        "version": version,
        "git_tree": tree,
        "sha512": sha512,
        "new": created,
    }


def refresh(root, port, base_url=""):
    """Re-read the port's description from its upstream repository; when it
    changed, record the change as the next port-version of the same release
    (vcpkg needs a new port-version for any change at one version)."""
    pdir = os.path.join(root, "ports", port)
    if not os.path.isdir(pdir):
        raise Failure(f"no ports/{port}")
    mpath = os.path.join(pdir, "vcpkg.json")
    manifest = read_json(mpath)
    key = version_key(manifest)
    version = manifest[key]
    text = read_text(os.path.join(pdir, "portfile.cmake"))
    if not is_github(text):
        print(
            f"port_bump: {port} {version}: not a GitHub release, description kept",
            file=sys.stderr,
        )
        return {"port": port, "version": version, "changed": False}
    url = asset_url(text, version, base_url)
    desc = upstream_description(url, base_url)
    if manifest.get("description") == desc:
        print(f"port_bump: {port} {version}: description current", file=sys.stderr)
        return {"port": port, "version": version, "changed": False}
    pv = manifest.get("port-version", 0) + 1
    manifest["description"] = desc
    manifest["port-version"] = pv
    write_json(mpath, manifest)
    tree = git_tree(root, port)
    vpath = versions_file(root, port)
    db = read_json(vpath)
    db["versions"].insert(0, {key: version, "port-version": pv, "git-tree": tree})
    write_json(vpath, db)
    bpath = os.path.join(root, "versions", "baseline.json")
    base = read_json(bpath)
    base["default"][port] = {"baseline": version, "port-version": pv}
    write_json(bpath, base)
    print(
        f"port_bump: {port} {version}#{pv}: description from upstream, git-tree {tree}",
        file=sys.stderr,
    )
    return {
        "port": port,
        "version": version,
        "port_version": pv,
        "git_tree": tree,
        "changed": True,
    }


def check(root):
    problems = []
    ports_dir = os.path.join(root, "ports")
    ports = sorted(os.listdir(ports_dir)) if os.path.isdir(ports_dir) else []
    tdir = os.path.join(root, "templates")
    for t in sorted(os.listdir(tdir)) if os.path.isdir(tdir) else []:
        if t in ports:
            problems.append(f"{t}: in both ports/ and templates/")
        tm = read_json(os.path.join(tdir, t, "vcpkg.json"))
        tp = read_text(os.path.join(tdir, t, "portfile.cmake"))
        if tm.get("name") != t:
            problems.append(f"templates/{t}: vcpkg.json names {tm.get('name')!r}")
        if not URLS_RE.search(tp) or not SHA512_RE.search(tp):
            problems.append(
                f"templates/{t}: portfile.cmake needs a URLS line and a SHA512 line"
            )
    bpath = os.path.join(root, "versions", "baseline.json")
    base = read_json(bpath)["default"] if os.path.exists(bpath) else {}
    for port in ports:
        manifest = read_json(os.path.join(ports_dir, port, "vcpkg.json"))
        key = version_key(manifest)
        version, pv = manifest[key], manifest.get("port-version", 0)
        if manifest.get("name") != port:
            problems.append(f"{port}: vcpkg.json names {manifest.get('name')!r}")
        b = base.get(port)
        if b != {"baseline": version, "port-version": pv}:
            problems.append(f"{port}: baseline {b} is not vcpkg.json's {version}#{pv}")
        vpath = versions_file(root, port)
        entries = read_json(vpath)["versions"] if os.path.exists(vpath) else []
        hit = [
            e
            for e in entries
            if e.get(key) == version and e.get("port-version", 0) == pv
        ]
        tree = git_tree(root, port)
        if not hit:
            problems.append(
                f"{port}: {version}#{pv} is not in {os.path.relpath(vpath, root)}"
            )
        elif hit[0]["git-tree"] != tree:
            problems.append(
                f"{port}: {version}#{pv} records git-tree {hit[0]['git-tree']}, "
                f"ports/{port} is {tree} (changed without a version or port-version bump?)"
            )
    for port in sorted(set(base) - set(ports)):
        problems.append(f"{port}: in the baseline but not in ports/")
    for p in problems:
        print(f"FAIL  {p}")
    print(f"port_bump check: {len(ports)} port(s), {len(problems)} problem(s)")
    return 1 if problems else 0


# --- self-test -------------------------------------------------------------


def self_test():
    fails = []

    def expect(cond, what):
        if not cond:
            fails.append(what)
            print(f"FAIL  {what}")

    def raises(fn, what, needle):
        try:
            fn()
        except Failure as e:
            expect(needle in str(e), f"{what}: message {e}")
            return
        fails.append(what)
        print(f"FAIL  {what}: no error")

    with tempfile.TemporaryDirectory() as tmp:
        repo, rel = os.path.join(tmp, "repo"), os.path.join(tmp, "rel")
        os.makedirs(repo)
        env_git = [
            "-c",
            "user.name=t",
            "-c",
            "user.email=t@t",
            "-c",
            "commit.gpgsign=false",
        ]
        git(repo, "init", "-q")

        def describe(repo_name, text):
            d = os.path.join(rel, "api", "repos", "o")
            os.makedirs(d, exist_ok=True)
            write_json(os.path.join(d, repo_name), {"description": text})

        describe("lib", "lib, a C++23 library")
        describe("next", "next, the next one")

        def release(version, data, sums_ok=True):
            d = os.path.join(rel, "o", "lib", "releases", "download", f"v{version}")
            os.makedirs(d, exist_ok=True)
            name = f"lib-{version}.tar.gz"
            with open(os.path.join(d, name), "wb") as f:
                f.write(data)
            digest = hashlib.sha256(data if sums_ok else b"other").hexdigest()
            with open(os.path.join(d, "SHA256SUMS"), "w") as f:
                f.write(f"{'0' * 64}  lib-{version}.cdx.json\n{digest}  {name}\n")

        portfile = (
            "vcpkg_download_distfile(ARCHIVE\n"
            '    URLS "https://github.com/o/lib/releases/download/v${VERSION}/lib-${VERSION}.tar.gz"\n'
            '    FILENAME "lib-${VERSION}.tar.gz"\n    SHA512 0\n)\n'
        )
        for d in ("ports/lib", "templates/next"):
            os.makedirs(os.path.join(repo, d))
            with open(os.path.join(repo, d, "portfile.cmake"), "w") as f:
                f.write(
                    portfile.replace("/lib/", "/next/").replace("lib-", "next-")
                    if "next" in d
                    else portfile
                )
            write_json(
                os.path.join(repo, d, "vcpkg.json"),
                {"name": d.split("/")[1], "version-semver": "0.0.0", "port-version": 3},
            )
        base = "file://" + rel
        release("1.2.0", b"one")
        r = bump(repo, "lib", "v1.2.0", base)
        git(repo, *env_git, "add", "-A")
        git(repo, *env_git, "commit", "-qm", "1.2.0")
        expect(
            r["git_tree"] == git(repo, "rev-parse", "HEAD:ports/lib"),
            "git-tree is git's own",
        )
        pf = read_text(os.path.join(repo, "ports/lib/portfile.cmake"))
        expect(
            hashlib.sha512(b"one").hexdigest() in pf,
            "SHA512 of the asset in the portfile",
        )
        m = read_json(os.path.join(repo, "ports/lib/vcpkg.json"))
        expect(
            m["version-semver"] == "1.2.0" and "port-version" not in m,
            "version written, port-version dropped",
        )
        expect(check(repo) == 0, "check passes after a bump")

        release("1.3.0", b"two")
        bump(repo, "lib", "v1.3.0", base)
        db = read_json(os.path.join(repo, "versions/l-/lib.json"))["versions"]
        expect([v["version-semver"] for v in db] == ["1.3.0", "1.2.0"], "newest first")
        expect(
            read_json(os.path.join(repo, "versions/baseline.json"))["default"]["lib"][
                "baseline"
            ]
            == "1.3.0",
            "baseline moved",
        )
        git(repo, *env_git, "add", "-A")
        git(repo, *env_git, "commit", "-qm", "1.3.0")
        before = read_text(os.path.join(repo, "versions/l-/lib.json"))
        bump(repo, "lib", "v1.3.0", base)
        expect(
            read_text(os.path.join(repo, "versions/l-/lib.json")) == before,
            "re-run is idempotent",
        )

        with open(os.path.join(repo, "ports/lib/usage"), "w") as f:
            f.write("changed\n")
        expect(check(repo) == 1, "check fails on a port changed without a bump")
        raises(
            lambda: bump(repo, "lib", "v1.3.0", base),
            "same version, other tree",
            "port-version",
        )
        expect(
            "1.3.0" in read_text(os.path.join(repo, "ports/lib/vcpkg.json"))
            and hashlib.sha512(b"two").hexdigest()
            in read_text(os.path.join(repo, "ports/lib/portfile.cmake")),
            "a refused bump restores the port's files",
        )
        os.remove(os.path.join(repo, "ports/lib/usage"))

        release("1.4.0", b"three", sums_ok=False)
        raises(
            lambda: bump(repo, "lib", "v1.4.0", base),
            "asset not in SHA256SUMS",
            "release lists",
        )
        raises(
            lambda: bump(repo, "lib", "v1.5.0", base),
            "no such release",
            "cannot download",
        )
        raises(lambda: bump(repo, "lib", "1.3.0", base), "tag without v", "vX.Y.Z")
        raises(
            lambda: bump(repo, "nope", "v1.3.0", base), "unknown port", "no ports/nope"
        )
        git(repo, "checkout", "-q", "--", ".")

        raises(
            lambda: bump(repo, "next", "v0.1.0", base),
            "a new port's release missing",
            "cannot download",
        )
        expect(
            os.path.isdir(os.path.join(repo, "templates/next"))
            and not os.path.exists(os.path.join(repo, "ports/next")),
            "a failed first bump keeps the template, writes no port",
        )
        vf = os.path.join(repo, "versions/l-/lib.json")
        saved = read_text(vf)
        db = read_json(vf)
        db["versions"].insert(0, {**db["versions"][0], "port-version": 1})
        write_json(vf, db)
        pf_before = read_text(os.path.join(repo, "ports/lib/portfile.cmake"))
        raises(
            lambda: bump(repo, "lib", "v1.3.0", base),
            "a recorded port-version is not reset",
            "port-version 1",
        )
        expect(
            read_text(os.path.join(repo, "ports/lib/portfile.cmake")) == pf_before,
            "the refusal writes nothing",
        )
        with open(vf, "w", encoding="utf-8") as f:
            f.write(saved)

        d = os.path.join(rel, "o", "next", "releases", "download", "v0.1.0")
        os.makedirs(d)
        with open(os.path.join(d, "next-0.1.0.tar.gz"), "wb") as f:
            f.write(b"new")
        with open(os.path.join(d, "SHA256SUMS"), "w") as f:
            f.write(f"{hashlib.sha256(b'new').hexdigest()}  next-0.1.0.tar.gz\n")
        os.rename(
            os.path.join(d, "SHA256SUMS"), os.path.join(d, "next-0.1.0.tar.gz.sha256")
        )
        r = bump(repo, "next", "v0.1.0", base)
        expect(
            r["new"] and os.path.isdir(os.path.join(repo, "ports/next")),
            "a new port from templates/",
        )
        expect(
            not os.path.exists(os.path.join(repo, "templates/next")),
            "template moved, not copied",
        )
        expect(check(repo) == 0, "check passes with two ports")
        expect(
            read_json(os.path.join(repo, "ports/lib/vcpkg.json"))["description"]
            == "lib, a C++23 library",
            "the description comes from the upstream repository",
        )
        r = refresh(repo, "lib", base)
        expect(not r["changed"], "refresh: an unchanged description writes nothing")
        describe("lib", "lib, a C++26 library")
        r = refresh(repo, "lib", base)
        m = read_json(os.path.join(repo, "ports/lib/vcpkg.json"))
        expect(
            r["changed"]
            and m["port-version"] == 1
            and m["description"] == "lib, a C++26 library",
            "refresh: a changed description is the next port-version",
        )
        expect(
            read_json(os.path.join(repo, "versions/baseline.json"))["default"]["lib"][
                "port-version"
            ]
            == 1
            and check(repo) == 0,
            "refresh: the baseline and versions/ follow; check passes",
        )
        raises(
            lambda: bump(repo, "lib", "v1.3.0", base),
            "a bump after a refresh keeps the port-version",
            "port-version 1",
        )
        base_db = read_json(os.path.join(repo, "versions/baseline.json"))["default"]
        expect(list(base_db) == ["lib", "next"], "baseline sorted")

        # A release outside GitHub (ns-3's tarball): its tag form and the page
        # that lists the asset's SHA-1, both declared in the portfile.
        sim = os.path.join(rel, "sim.example", "releases")
        os.makedirs(os.path.join(sim, "sim-3-9", "download"))
        with open(os.path.join(sim, "sim-3.9.tar.bz2"), "wb") as f:
            f.write(b"sim")

        def page(text):
            with open(os.path.join(sim, "sim-3-9", "download", "index"), "w") as f:
                f.write(text)

        os.makedirs(os.path.join(repo, "ports/sim"))
        with open(os.path.join(repo, "ports/sim/portfile.cmake"), "w") as f:
            f.write(
                "# RELEASE_TAG sim-${VERSION}\n"
                "# CHECKSUM_PAGE https://sim.example/releases/sim-${VERSION_DASHED}/download/index\n"
                'vcpkg_download_distfile(ARCHIVE\n    URLS "https://sim.example/releases/sim-${VERSION}.tar.bz2"\n'
                '    FILENAME "sim-${VERSION}.tar.bz2"\n    SHA512 0\n)\n'
            )
        write_json(
            os.path.join(repo, "ports/sim/vcpkg.json"),
            {"name": "sim", "version": "3.8", "description": "sim, kept"},
        )
        page(f"<p>sha1sum: {hashlib.sha1(b'other').hexdigest()}</p>")
        raises(
            lambda: bump(repo, "sim", "sim-3.9", base),
            "asset not on its checksum page",
            "nor its sha1",
        )
        raises(lambda: bump(repo, "sim", "v3.9.0", base), "tag form", "sim-X.Y")
        write_json(
            os.path.join(repo, "ports/sim/vcpkg.json"),
            {"name": "sim", "version-semver": "3.8.0", "description": "sim, kept"},
        )
        raises(
            lambda: bump(repo, "sim", "sim-3.9", base),
            "an X.Y release under version-semver",
            "needs X.Y.Z",
        )
        write_json(
            os.path.join(repo, "ports/sim/vcpkg.json"),
            {"name": "sim", "version": "3.8", "description": "sim, kept"},
        )
        page(f"<p>sha1sum: {hashlib.sha1(b'sim').hexdigest()}</p>")
        r = bump(repo, "sim", "sim-3.9", base)
        m = read_json(os.path.join(repo, "ports/sim/vcpkg.json"))
        expect(
            r["version"] == "3.9" and m["version"] == "3.9",
            "a sim-X.Y tag gives version X.Y",
        )
        expect(
            m["description"] == "sim, kept"
            and hashlib.sha512(b"sim").hexdigest()
            in read_text(os.path.join(repo, "ports/sim/portfile.cmake")),
            "outside GitHub: SHA512 written, description kept",
        )
        expect(
            not refresh(repo, "sim", base)["changed"] and check(repo) == 0,
            "refresh keeps an outside port's description; check passes",
        )
        with open(os.path.join(repo, "ports/sim/portfile.cmake"), "w") as f:
            f.write(
                'vcpkg_download_distfile(ARCHIVE\n    URLS "https://sim.example/releases/sim-${VERSION}.tar.bz2"\n'
                "    SHA512 0\n)\n"
            )
        raises(
            lambda: bump(repo, "sim", "v3.9.0", base),
            "outside GitHub without a checksum page",
            "CHECKSUM_PAGE",
        )

    print(f"port_bump self-test: {'ok' if not fails else f'{len(fails)} failure(s)'}")
    return 1 if fails else 0


def main(argv=None):
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("--self-test", action="store_true")
    sub = ap.add_subparsers(dest="cmd")
    b = sub.add_parser("bump", help="render a port bump from a published release")
    b.add_argument("--port", required=True)
    b.add_argument("--tag", required=True)
    b.add_argument("--root", default=".")
    b.add_argument(
        "--base-url", default="", help="replaces https://github.com/ in the asset URL"
    )
    b.add_argument(
        "--json",
        action="store_true",
        help="print the result as JSON (for the release job)",
    )
    f = sub.add_parser(
        "refresh", help="the port's description from its upstream repository"
    )
    f.add_argument("--port", required=True)
    f.add_argument("--root", default=".")
    f.add_argument("--base-url", default="")
    c = sub.add_parser("check", help="versions/ matches ports/")
    c.add_argument("--root", default=".")
    a = ap.parse_args(argv)
    if a.self_test:
        return self_test()
    if a.cmd == "bump":
        r = bump(os.path.abspath(a.root), a.port, a.tag, a.base_url)
        if a.json:
            print(json.dumps(r))
        return 0
    if a.cmd == "refresh":
        refresh(os.path.abspath(a.root), a.port, a.base_url)
        return 0
    if a.cmd == "check":
        return check(os.path.abspath(a.root))
    ap.print_help()
    return 2


if __name__ == "__main__":
    sys.exit(main())
