#!/usr/bin/env python3
"""
Copy a Mach-O binary's non-system dynamic libraries into the bundle and rewrite
references to @executable_path/../lib/<name>, recursively.

This replaces dylibbundler, which cannot resolve @executable_path references on
a relocated binary (modern Homebrew ships relocatable binaries that use
@executable_path/../lib/...). We resolve each dependency by name from the given
search directories and copy it in.

Usage: bundle-libs.py <bundle_lib_dir> <search_dirs_comma_sep> <binary> [binary...]
"""
import os
import shutil
import subprocess
import sys

lib_dir = sys.argv[1]
search_dirs = [d for d in sys.argv[2].split(",") if d]
binaries = sys.argv[3:]
os.makedirs(lib_dir, exist_ok=True)


def deps(path):
    out = subprocess.run(["otool", "-L", path], capture_output=True, text=True).stdout
    lines = out.splitlines()[1:]  # first line is the file name
    result = []
    for line in lines:
        line = line.strip()
        if not line:
            continue
        result.append(line.split(" (")[0].strip())
    return result


def is_system(dep):
    return dep.startswith("/usr/lib/") or dep.startswith("/System/")


def find_real(name):
    for d in search_dirs:
        p = os.path.join(d, name)
        if os.path.exists(p):
            return os.path.realpath(p)
    return None


def rewrite(target, old, new):
    subprocess.run(["install_name_tool", "-change", old, new, target],
                   stderr=subprocess.DEVNULL)


def process(target, is_dylib):
    target_name = os.path.basename(target)
    for dep in deps(target):
        if is_system(dep):
            continue
        name = os.path.basename(dep)
        new_ref = "@executable_path/../lib/" + name
        # A dylib's first otool entry is its own install id.
        if is_dylib and name == target_name:
            subprocess.run(["install_name_tool", "-id", new_ref, target],
                           stderr=subprocess.DEVNULL)
            continue
        dest = os.path.join(lib_dir, name)
        if not os.path.exists(dest):
            src = os.path.realpath(dep) if (dep.startswith("/") and os.path.exists(dep)) else find_real(name)
            if not src or not os.path.exists(src):
                print(f"  ! cannot locate {name} (from {dep})")
                rewrite(target, dep, new_ref)
                continue
            shutil.copy(src, dest)
            os.chmod(dest, 0o755)
            rewrite(target, dep, new_ref)
            process(dest, True)  # recurse into the freshly copied lib
        else:
            rewrite(target, dep, new_ref)


for b in binaries:
    if os.path.exists(b):
        print(f"  bundling libs for {os.path.basename(b)}")
        process(b, False)

print(f"  -> {len(os.listdir(lib_dir))} libs in {lib_dir}")
