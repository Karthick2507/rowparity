"""``python -m prism`` — PRISM is a utility you run, never a package you install.

There is deliberately no ``[project.scripts]`` entry for it. rowparity is the
product; PRISM is a tool that writes files for it, and a tool that installs
itself onto everyone's PATH alongside the thing it generates for invites exactly
the confusion this separation exists to avoid.
"""
import sys

from .cli import main

if __name__ == "__main__":
    sys.exit(main())
